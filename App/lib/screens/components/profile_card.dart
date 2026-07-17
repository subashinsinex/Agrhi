import 'dart:io';
import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  final String name;
  final String? email;
  final String? category;
  final bool emailVerified;
  final String? profileImagePath;
  final VoidCallback? onTap;

  const ProfileCard({
    super.key,
    required this.name,
    this.email,
    this.category,
    this.emailVerified = false,
    this.profileImagePath,
    this.onTap,
  });

  String formatCategory(String? value) {
    if (value == null || value.trim().isEmpty) return 'Guest User';
    final text = value.trim();
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final safeName = name.trim().isEmpty ? 'Guest User' : name.trim();
    final safeEmail = email?.trim();
    final safeCategory = formatCategory(category);
    final hasEmail = safeEmail != null && safeEmail.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD6DFC7)),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildAvatar(safeName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildStatusChip(safeCategory, false),
                        if (emailVerified) _buildStatusChip('Verified', true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        safeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF234E22),
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5E4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            size: 15,
                            color: Color(0xFF5B7E52),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              hasEmail ? safeEmail : 'Welcome back to AGRHI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF527248),
                                fontSize: 11.8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF0F5E4),
                  border: Border.all(color: const Color(0xFFD8E2C8)),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF5B7E52),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String text, bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFF0F5E4) : const Color(0xFFD8F0F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isVerified ? const Color(0xFFD7E1C7) : const Color(0xFFB5DDE5),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isVerified ? const Color(0xFF54714D) : const Color(0xFF2E6F7A),
          fontSize: 10.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAvatar(String safeName) {
    final rawPath = profileImagePath?.trim();
    final hasImage = rawPath != null && rawPath.isNotEmpty;
    final file = hasImage ? File(rawPath) : null;
    final fileExists = file != null && file.existsSync();

    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD5DEC6)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: fileExists
            ? Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitialAvatar(safeName),
              )
            : _buildInitialAvatar(safeName),
      ),
    );
  }

  Widget _buildInitialAvatar(String safeName) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6E2FC8), Color(0xFF1C103A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        safeName.isNotEmpty ? safeName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
