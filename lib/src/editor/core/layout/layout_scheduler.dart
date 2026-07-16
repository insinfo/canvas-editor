import 'dart:async';

typedef LayoutCallback = void Function();
typedef LayoutCancel = void Function();
typedef LayoutClock = Duration Function();
typedef LayoutSchedule = LayoutCancel Function(LayoutCallback callback);
typedef LayoutCommit = void Function();
typedef LayoutErrorCallback = void Function(
    Object error, StackTrace stackTrace);

typedef LayoutStep<C, T> = LayoutStepResult<C> Function(
  LayoutSlice<C, T> slice,
);

/// Contexto de uma unidade de trabalho executada dentro de um frame.
///
/// [deadline] usa o mesmo dominio monotono de [LayoutClock]. Um step que faz
/// trabalho interno adicional pode consultar [shouldYield] para cooperar com o
/// orcamento sem depender de uma quantidade fixa de itens.
class LayoutSlice<C, T> {
  const LayoutSlice._({
    required this.version,
    required this.continuation,
    required this.target,
    required this.deadline,
    required LayoutClock clock,
    required bool Function() isCurrent,
  })  : _clock = clock,
        _isCurrent = isCurrent;

  final int version;
  final C? continuation;
  final T? target;
  final Duration deadline;

  final LayoutClock _clock;
  final bool Function() _isCurrent;

  bool get isCurrent => _isCurrent();

  Duration get remainingBudget {
    final Duration now = _clock();
    return now.compareTo(deadline) >= 0 ? Duration.zero : deadline - now;
  }

  bool get shouldYield => !isCurrent || remainingBudget == Duration.zero;
}

/// Resultado de uma unidade cooperativa de layout.
///
/// Mutacoes no estado publicado devem ficar em [commit], nao em
/// [LayoutStep]. Assim o scheduler consegue descartar o resultado se o job
/// for cancelado ou substituido enquanto o step calcula.
class LayoutStepResult<C> {
  const LayoutStepResult({
    this.continuation,
    this.commit,
    this.isComplete = false,
    this.targetReached = false,
  });

  const LayoutStepResult.complete({this.commit})
      : continuation = null,
        isComplete = true,
        targetReached = false;

  final C? continuation;
  final LayoutCommit? commit;
  final bool isComplete;
  final bool targetReached;
}

/// Executa layout em fatias limitadas por tempo, com cancelamento por versao.
///
/// O callback fornecido por [schedule] deve enfileirar o trabalho para uma
/// execucao futura e devolver uma funcao de cancelamento. O padrao usa
/// um [Timer] de duracao zero, portanto funciona tanto na VM quanto no browser.
class LayoutScheduler<C, T> {
  factory LayoutScheduler({
    Duration frameBudget = const Duration(milliseconds: 10),
    LayoutClock? clock,
    LayoutSchedule? schedule,
  }) {
    if (frameBudget <= Duration.zero) {
      throw ArgumentError.value(
        frameBudget,
        'frameBudget',
        'must be greater than zero',
      );
    }
    return LayoutScheduler<C, T>._(
      frameBudget: frameBudget,
      clock: clock ?? _createMonotonicClock(),
      schedule: schedule ?? _scheduleWithTimer,
    );
  }

  LayoutScheduler._({
    required this.frameBudget,
    required LayoutClock clock,
    required LayoutSchedule schedule,
  })  : _clock = clock,
        _schedule = schedule;

  final Duration frameBudget;
  final LayoutClock _clock;
  final LayoutSchedule _schedule;

  int _version = 0;
  int _targetRevision = 0;
  int? _scheduledVersion;
  LayoutCancel? _cancelScheduled;

  bool _hasJob = false;
  bool _paused = false;
  C? _continuation;
  T? _target;
  LayoutStep<C, T>? _step;
  LayoutCallback? _onComplete;
  LayoutCallback? _onTargetReached;
  LayoutErrorCallback? _onError;

  int get version => _version;

  bool get hasJob => _hasJob;

  bool get isActive => _hasJob && !_paused;

  bool get isPaused => _hasJob && _paused;

  C? get continuation => _continuation;

  T? get target => _target;

  /// Substitui qualquer job anterior e agenda a primeira fatia.
  ///
  /// O inteiro retornado identifica a versao do novo job.
  int start({
    C? continuation,
    T? target,
    required LayoutStep<C, T> step,
    LayoutCallback? onComplete,
    LayoutCallback? onTargetReached,
    LayoutErrorCallback? onError,
  }) {
    _invalidateCurrentJob();
    _hasJob = true;
    _paused = false;
    _continuation = continuation;
    _target = target;
    _targetRevision += 1;
    _step = step;
    _onComplete = onComplete;
    _onTargetReached = onTargetReached;
    _onError = onError;
    _ensureScheduled(_version);
    return _version;
  }

  /// Atualiza o alvo do job corrente e retoma um job pausado no alvo anterior.
  bool requestTarget(T? target) {
    if (!_hasJob) {
      return false;
    }
    _target = target;
    _targetRevision += 1;
    if (_paused) {
      _paused = false;
      _ensureScheduled(_version);
    }
    return true;
  }

  /// Retoma a continuacao preservando o alvo atual.
  bool resume() {
    if (!_hasJob || !_paused) {
      return false;
    }
    _paused = false;
    _ensureScheduled(_version);
    return true;
  }

  /// Cancela o job e invalida callbacks ja enfileirados.
  bool cancel() {
    if (!_hasJob && _scheduledVersion == null) {
      return false;
    }
    _invalidateCurrentJob();
    return true;
  }

  void _ensureScheduled(int jobVersion) {
    if (!_isCurrent(jobVersion) || _paused) {
      return;
    }
    if (_scheduledVersion == jobVersion) {
      return;
    }

    _cancelPendingCallback();
    _scheduledVersion = jobVersion;
    _cancelScheduled = _schedule(() {
      if (_scheduledVersion == jobVersion) {
        _scheduledVersion = null;
        _cancelScheduled = null;
      }
      _drain(jobVersion);
    });
  }

  void _drain(int jobVersion) {
    if (!_isCurrent(jobVersion) || _paused) {
      return;
    }

    final Duration deadline = _clock() + frameBudget;
    while (_isCurrent(jobVersion) && !_paused) {
      if (_clock().compareTo(deadline) >= 0) {
        _ensureScheduled(jobVersion);
        return;
      }

      final LayoutStep<C, T>? step = _step;
      if (step == null) {
        return;
      }
      final int targetRevision = _targetRevision;
      final LayoutSlice<C, T> slice = LayoutSlice<C, T>._(
        version: jobVersion,
        continuation: _continuation,
        target: _target,
        deadline: deadline,
        clock: _clock,
        isCurrent: () => _isCurrent(jobVersion),
      );

      final LayoutStepResult<C> result;
      try {
        result = step(slice);
      } catch (error, stackTrace) {
        _fail(jobVersion, error, stackTrace);
        return;
      }

      // O step pode cancelar ou substituir o proprio job. Nesse caso o
      // resultado calculado pertence a uma versao stale e nunca e publicado.
      if (!_isCurrent(jobVersion)) {
        return;
      }
      try {
        result.commit?.call();
      } catch (error, stackTrace) {
        _fail(jobVersion, error, stackTrace);
        return;
      }
      if (!_isCurrent(jobVersion)) {
        return;
      }

      _continuation = result.continuation;
      if (result.isComplete) {
        _complete(jobVersion);
        return;
      }

      // Se o alvo mudou durante o step/commit, a resposta targetReached se
      // refere ao alvo antigo. Preservamos o progresso e continuamos.
      if (result.targetReached && targetRevision == _targetRevision) {
        _paused = true;
        final LayoutCallback? callback = _onTargetReached;
        if (_isCurrent(jobVersion)) {
          callback?.call();
        }
        return;
      }
    }
  }

  void _complete(int jobVersion) {
    if (!_isCurrent(jobVersion)) {
      return;
    }
    final LayoutCallback? callback = _onComplete;
    _clearJob();
    callback?.call();
  }

  void _fail(int jobVersion, Object error, StackTrace stackTrace) {
    if (!_isCurrent(jobVersion)) {
      return;
    }
    final LayoutErrorCallback? callback = _onError;
    _invalidateCurrentJob();
    if (callback != null) {
      callback(error, stackTrace);
      return;
    }
    Error.throwWithStackTrace(error, stackTrace);
  }

  bool _isCurrent(int jobVersion) => _hasJob && jobVersion == _version;

  void _invalidateCurrentJob() {
    _version += 1;
    _cancelPendingCallback();
    _clearJob();
  }

  void _cancelPendingCallback() {
    _cancelScheduled?.call();
    _cancelScheduled = null;
    _scheduledVersion = null;
  }

  void _clearJob() {
    _hasJob = false;
    _paused = false;
    _continuation = null;
    _target = null;
    _step = null;
    _onComplete = null;
    _onTargetReached = null;
    _onError = null;
  }

  static LayoutClock _createMonotonicClock() {
    final Stopwatch stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  static LayoutCancel _scheduleWithTimer(LayoutCallback callback) {
    final Timer timer = Timer(Duration.zero, callback);
    return timer.cancel;
  }
}
