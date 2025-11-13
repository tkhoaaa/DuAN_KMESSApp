enum FollowStatus { self, following, requested, none }

class FollowState {
  const FollowState({
    required this.status,
    required this.isTargetPrivate,
  });

  final FollowStatus status;
  final bool isTargetPrivate;
}

