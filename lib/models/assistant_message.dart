enum AssistantRole { user, assistant }

final class AssistantMessage {
  const AssistantMessage({required this.role, required this.content});

  final AssistantRole role;
  final String content;
}
