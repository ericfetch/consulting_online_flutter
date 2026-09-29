class CopilotReply {
  final String id, label, staffText, customerText, customerLanguage;
  const CopilotReply(
      {required this.id,
      required this.label,
      required this.staffText,
      required this.customerText,
      required this.customerLanguage});
  factory CopilotReply.fromJson(Map<String, dynamic> json) => CopilotReply(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        staffText: json['staffText'] as String? ?? '',
        customerText: json['customerText'] as String? ?? '',
        customerLanguage: json['customerLanguage'] as String? ?? '',
      );
}

class CopilotCard {
  final String kind;
  final Map<String, dynamic> data;
  const CopilotCard(this.kind, this.data);
  factory CopilotCard.fromJson(Map<String, dynamic> json) =>
      CopilotCard(json['kind'] as String? ?? '', json);
  String text(String key) => data[key] as String? ?? '';
  List<String> lines(String key) =>
      (data[key] as List? ?? []).whereType<String>().toList();
  List<Map<String, dynamic>> objects(String key) => (data[key] as List? ?? [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  List<CopilotReply> get options =>
      objects('options').map(CopilotReply.fromJson).toList();
}

class CopilotEvent {
  final String id, kind, text;
  final CopilotCard? card;
  final DateTime? at;
  const CopilotEvent(
      {required this.id,
      required this.kind,
      required this.text,
      this.card,
      this.at});
  factory CopilotEvent.fromJson(Map<String, dynamic> json) => CopilotEvent(
        id: json['id'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        text: json['text'] as String? ?? '',
        card: json['card'] is Map
            ? CopilotCard.fromJson(
                Map<String, dynamic>.from(json['card'] as Map))
            : null,
        at: DateTime.tryParse(json['at'] as String? ?? ''),
      );
}

class CopilotRun {
  final String id, trigger, prompt, status;
  final String? sourceMessageId;
  final List<CopilotEvent> events;
  final String purpose;
  final DateTime? createdAt;
  const CopilotRun(
      {required this.id,
      required this.trigger,
      required this.prompt,
      required this.status,
      this.sourceMessageId,
      this.purpose = 'assist',
      this.createdAt,
      required this.events});
  factory CopilotRun.fromJson(Map<String, dynamic> json) => CopilotRun(
        id: json['id'] as String? ?? '',
        trigger: json['trigger'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        status: json['status'] as String? ?? '',
        sourceMessageId: json['sourceMessageId'] as String?,
        purpose: json['purpose'] as String? ?? 'assist',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        events: (json['events'] as List? ?? [])
            .whereType<Map>()
            .map((item) =>
                CopilotEvent.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
  bool get running => status == 'RUNNING';
  String get progress =>
      events.where((event) => event.kind == 'status').lastOrNull?.text ??
      '正在分析当前对话';
  bool get completed => status == 'COMPLETED';
}

class CopilotSnapshot {
  final bool enabled, autoSuggest;
  final String? latestMessageId;
  final List<CopilotRun> runs;
  final List<CopilotTranslation> translations;
  final List<MediaRecognition> recognitions;
  final bool visionEnabled, asrEnabled;
  const CopilotSnapshot(
      {required this.enabled,
      required this.autoSuggest,
      this.latestMessageId,
      this.translations = const [],
      this.recognitions = const [],
      this.visionEnabled = false,
      this.asrEnabled = false,
      required this.runs});
  factory CopilotSnapshot.fromJson(Map<String, dynamic> json) =>
      CopilotSnapshot(
        enabled: json['enabled'] == true,
        autoSuggest: json['autoSuggest'] == true,
        latestMessageId: json['latestMessageId'] as String?,
        visionEnabled: json['visionEnabled'] == true,
        asrEnabled: json['asrEnabled'] == true,
        translations: (json['translations'] as List? ?? [])
            .map((e) =>
                CopilotTranslation.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        recognitions: (json['recognitions'] as List? ?? [])
            .map((e) => MediaRecognition.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        runs: (json['runs'] as List? ?? [])
            .whereType<Map>()
            .map((item) => CopilotRun.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class CopilotTranslation {
  final String messageId, status, text, sourceLanguage, error;
  CopilotTranslation.fromJson(Map<String, dynamic> json)
      : messageId = json['messageId'] ?? '',
        status = json['status'] ?? '',
        text = json['text'] ?? '',
        sourceLanguage = json['sourceLanguage'] ?? '',
        error = json['error'] ?? '';
}

class MediaRecognition {
  final String messageId, kind, status, text, translatedText, summary, error;
  final int attachmentIndex;
  MediaRecognition.fromJson(Map<String, dynamic> json)
      : messageId = json['messageId'] ?? '',
        kind = json['kind'] ?? '',
        status = json['status'] ?? '',
        text = json['text'] ?? '',
        translatedText = json['translatedText'] ?? '',
        summary = json['summary'] ?? '',
        error = json['error'] ?? '',
        attachmentIndex = json['attachmentIndex'] ?? 0;
  bool get running => status == 'PENDING' || status == 'RUNNING';
}

const replyPrompt =
    '结合触发点之前的对话，用一句话给客服建议方向，不复述客户消息。使用 show_reply_options 给出 2–3 个马上可用的客户语言回复，简单场景只给 1 个。每个选项的 staffText 必须是对应原文的完整简体中文译文。不要另行重复翻译或列待确认清单。';
const summaryPrompt =
    '请仅依据客户发来的消息、填写资料和提交的报告，简洁汇总基本资料、客户诉求、自述病情及已读取的报告事实，使用 save_customer_profile 保存。排除客服消息、AI 回复、分析和历史摘要，不添加诊断或建议。未知信息不猜测，未读附件仅归档，不必逐个解读。';

bool isCopilotMention(String text) =>
    RegExp(r'^\s*@agent\b', caseSensitive: false).hasMatch(text);
String copilotQuestion(String text) => text
    .replaceFirst(RegExp(r'^\s*@agent\b[\s:：]*', caseSensitive: false), '')
    .trim();
