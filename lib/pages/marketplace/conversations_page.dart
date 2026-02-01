import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/models/chat.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/pages/marketplace/chat_room.dart';
import 'package:intl/intl.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final ApiService _apiService = ApiService();
  List<MarketplaceConversation> _conversations = [];
  bool _isLoading = true;
  String? _userId;

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _userId = await _apiService.getDatabaseUserId();
    _conversations = await _apiService.getConversations();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} selected' : 'Messages',
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _deleteSelectedConversations,
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => const ListTileShimmer(),
            )
          : _conversations.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: _conversations.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final convo = _conversations[index];
                  final isSelected = _selectedIds.contains(convo.id);

                  return _ConversationTile(
                    conversation: convo,
                    currentUserId: _userId,
                    isSelected: isSelected,
                    isSelectionMode: _isSelectionMode,
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(convo.id);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChatRoomPage(conversation: convo),
                          ),
                        ).then((_) => _loadData());
                      }
                    },
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedIds.add(convo.id);
                        });
                      }
                    },
                  );
                },
              ),
            ),
    );
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedConversations() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversations'),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} conversations?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      for (final id in _selectedIds) {
        await _apiService.deleteConversation(id);
      }
      _selectedIds.clear();
      _isSelectionMode = false;
      await _loadData();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No conversations yet',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Messages with buyers and sellers will appear here',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final MarketplaceConversation conversation;
  final String? currentUserId;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isBuyer = currentUserId == conversation.buyerId;
    final otherUser = isBuyer ? conversation.seller : conversation.buyer;
    final lastMsg = conversation.lastMessage;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.05),
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: otherUser?.image != null
                ? CachedNetworkImageProvider(otherUser!.image!)
                : null,
            child: otherUser?.image == null
                ? Text(
                    otherUser?.name.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          if (isSelectionMode && isSelected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 20),
              ),
            ),
          if (!isSelectionMode && conversation.listing?.primaryImageUrl != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: conversation.listing!.primaryImageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUser?.name ?? 'Unknown User',
              style: AppTextStyles.labelLarge,
            ),
          ),
          if (lastMsg != null)
            Text(
              _formatDate(lastMsg.createdAt),
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversation.listing?.title ?? 'Listing Removed',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            lastMsg?.content ?? 'Starting a conversation...',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight:
                  (lastMsg != null &&
                      !lastMsg.isRead &&
                      lastMsg.senderId != currentUserId)
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat.jm().format(date);
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(date);
    } else {
      return DateFormat.yMd().format(date);
    }
  }
}
