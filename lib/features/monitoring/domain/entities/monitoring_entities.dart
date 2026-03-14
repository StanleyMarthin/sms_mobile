library;

class MonitoringDivisionProgress {
  const MonitoringDivisionProgress({
    required this.divisionName,
    required this.progressPercentage,
    required this.weeklyWorkHours,
    required this.remainingHours,
    this.blockedJobs = 0,
    this.overdueJobs = 0,
    this.forecastFinishDate,
    this.note,
  });

  final String divisionName;
  final int progressPercentage;
  final double weeklyWorkHours;
  final double remainingHours;
  final int blockedJobs;
  final int overdueJobs;
  final String? forecastFinishDate;
  final String? note;
}

class MonitoringCar {
  const MonitoringCar({
    required this.carId,
    required this.unitName,
    required this.owner,
    required this.isMargin,
    required this.avgProgressPercentage,
    required this.status,
    required this.divisions,
    required this.remainingWorkHours,
    this.deliveryDate,
    this.projectStartDate,
    this.lastUpdateDate,
    this.nextMilestone,
  });

  final String carId;
  final String unitName;
  final String owner;
  final bool isMargin;
  final int avgProgressPercentage;
  final String status;
  final List<MonitoringDivisionProgress> divisions;
  final double remainingWorkHours;
  final String? deliveryDate;
  final String? projectStartDate;
  final String? lastUpdateDate;
  final String? nextMilestone;
}