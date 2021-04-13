extension ObjectContinuation<I extends Object> on I {
  R map<R>(R Function(I) func) => func(this);
}

extension Function2ApplyExtension<T, P1, P2> on T Function(P1, P2) {
  T Function(P2) apply(P1 p1) => (p2) => this(p1, p2);
}

String firstLetterUpperCased(String input) =>
    input.substring(0, 1).toUpperCase() + input.substring(1);
