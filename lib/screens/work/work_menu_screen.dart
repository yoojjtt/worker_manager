import 'package:flutter/material.dart';

import '../placeholder_screen.dart';
import 'approval_list_screen.dart';

// Design Ref: §5.2 — 업무관리 메뉴 2x2 그리드
class WorkMenuScreen extends StatelessWidget {
  const WorkMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menus = [
      _MenuItem(
        icon: Icons.qr_code,
        label: 'QR 생성',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PlaceholderScreen(
              title: 'QR 생성',
              icon: Icons.qr_code,
            ),
          ),
        ),
      ),
      _MenuItem(
        icon: Icons.health_and_safety,
        label: '안전보고서',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PlaceholderScreen(
              title: '안전보고서',
              icon: Icons.health_and_safety,
            ),
          ),
        ),
      ),
      _MenuItem(
        icon: Icons.add_task,
        label: '작업추가',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PlaceholderScreen(
              title: '작업추가',
              icon: Icons.add_task,
            ),
          ),
        ),
      ),
      _MenuItem(
        icon: Icons.receipt_long,
        label: '결재요청',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ApprovalListScreen(),
          ),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        itemCount: menus.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemBuilder: (context, index) {
          final menu = menus[index];
          return GestureDetector(
            onTap: menu.onTap,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2E5C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      menu.icon,
                      size: 28,
                      color: const Color(0xFF1B2E5C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    menu.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3A3A3A),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
