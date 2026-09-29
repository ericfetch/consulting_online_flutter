import '../../../data/models/user.dart';

// A late HTTP or reconnect snapshot must not overwrite a newer manual choice.
AgentUser latestAgentAvailability(AgentUser? current, AgentUser incoming) {
  if (current == null ||
      current.id != incoming.id ||
      current.updatedAt == null) {
    return incoming;
  }
  if (incoming.updatedAt == null ||
      incoming.updatedAt!.isBefore(current.updatedAt!)) {
    return incoming.copyWith(
        agentStatus: current.agentStatus, updatedAt: current.updatedAt);
  }
  return incoming;
}
