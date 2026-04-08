double runningMax(double currentValue, double? previousMax) {
	final prev = previousMax ?? double.negativeInfinity;
	return currentValue > prev ? currentValue : prev;
}

