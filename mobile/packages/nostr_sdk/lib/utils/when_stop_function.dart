mixin WhenStopFunction {
  bool _WhenStopRunning = true;

  int whenStopMS = 200;

  int stopTime = 0;

  bool waitingStop = false;

  void whenStop(Function func) {
    _updateStopTime();
    if (!waitingStop) {
      waitingStop = true;
      _goWaitForStop(func);
    }
  }

  void _updateStopTime() {
    stopTime = DateTime.now().millisecondsSinceEpoch + whenStopMS;
  }

  void _goWaitForStop(Function func) {
    Future.delayed(Duration(milliseconds: whenStopMS), () {
      if (!_WhenStopRunning) {
        return;
      }

      var nowMS = DateTime.now().millisecondsSinceEpoch;
      if (nowMS >= stopTime) {
        func();
        waitingStop = false;
      } else {
        _goWaitForStop(func);
      }
    });
  }

  void disposeWhenStop() {
    _WhenStopRunning = false;
  }
}
