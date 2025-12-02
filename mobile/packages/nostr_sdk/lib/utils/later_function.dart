mixin LaterFunction {
  int laterTimeMS = 200;

  bool latering = false;

  bool _running = true;

  void later(Function func) {
    if (latering) {
      return;
    }

    latering = true;
    Future.delayed(Duration(milliseconds: laterTimeMS), () {
      if (!_running) {
        return;
      }

      latering = false;
      func();
    });
  }

  void disposeLater() {
    _running = false;
  }
}
