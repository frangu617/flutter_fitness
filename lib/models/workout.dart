enum WorkoutType { cardio, strength }

class WorkoutSet {
  final int reps;
  final double? weight;
  final bool isBodyweight;

  WorkoutSet({required this.reps, this.weight, this.isBodyweight = false});
}

abstract class Workout {
  final String id;
  final String name;
  final WorkoutType type;

  Workout({required this.id, required this.name, required this.type});
}

class CardioWorkout extends Workout {
  final double? distance; // in miles or km
  final int? time; // in minutes

  CardioWorkout({
    required super.id,
    required super.name,
    this.distance,
    this.time,
  }) : super(type: WorkoutType.cardio);
}

class StrengthWorkout extends Workout {
  final List<WorkoutSet> sets;

  StrengthWorkout({
    required super.id,
    required super.name,
    List<WorkoutSet>? sets,
  }) : sets = sets ?? [],
       super(type: WorkoutType.strength);
}
