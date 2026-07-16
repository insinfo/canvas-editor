/// Forward-only model change retained by an absolute history checkpoint.
///
/// Unlike a normal undo mutation, a checkpoint delta does not need the values
/// it removed. It only has to recreate the endpoint after the absolute
/// baseline was restored. Implementations may therefore discard old undo
/// payload and algebraically merge adjacent changes.
abstract interface class DocumentReplayDelta {
  /// Applies this forward change without restoring view state or rendering.
  void replay();

  /// Creates an independently mutable checkpoint representation.
  DocumentReplayDelta copyForCheckpoint();

  /// Attempts to append [next] to this checkpoint delta in place.
  bool tryMergeCheckpoint(DocumentReplayDelta next);

  /// Number of primitive model operations performed by [replay].
  int get replayOperationCount;

  /// Approximate retained element/value units owned by this delta.
  int get retainedPayloadUnits;
}
