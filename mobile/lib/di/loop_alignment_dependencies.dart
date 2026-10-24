// ABOUTME: Creates an editor-scoped loop repair repository and native client.
import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:openvine/services/video_editor/native_loop_alignment_client.dart';

LoopAlignmentRepository createLoopAlignmentRepository() =>
    LoopAlignmentRepository(client: NativeLoopAlignmentClient());
