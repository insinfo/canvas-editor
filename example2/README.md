# Exemplo AngularDart + Limitless UI

```powershell
dart pub get
dart run build_runner build --delete-conflicting-outputs
webdev serve web:8081 
```

O componente Angular cria `CanvasEditorWidget` em `ngAfterViewInit` e chama
`destroy()` em `ngOnDestroy`. O seletor de modo alterna entre edição e
visualização somente leitura sem recriar o documento.
