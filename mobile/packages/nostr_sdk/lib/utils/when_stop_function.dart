// ABOUTME: Mixin providing debounce functionality for delayed function execution.
// ABOUTME: Executes a function only after user input has stopped for a specified duration.

mixin WhenStopFunction {
  bool _whenStopRunning = true;

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
      if (!_whenStopRunning) {
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
    _whenStopRunning = false;
  }
}
