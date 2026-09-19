import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/finance_repository.dart';
import '../models/transaction.dart';
import '../security/security_service.dart';
import '../theme.dart';
import '../utils/app_info.dart';
import '../utils/format.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class DashboardTab extends StatelessWidget {
  final VoidCallback onShowAll;

  const DashboardTab({super.key, required this.onShowAll});

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;

    return ValueListenableBuilder(
      valueListenable: repo.categoriesListenable,
      builder: (context, _, __) {
        return ValueListenableBuilder(
          valueListenable: repo.transactionsListenable,
          builder: (context, _, __) {
            final now = DateTime.now();
            final balance = repo.getBalance();
            final income = repo.getMonthIncome(now);
            final expense = repo.getMonthExpense(now);

            final transactions =
                repo.getTransactions()
                  ..sort((a, b) => b.date.compareTo(a.date));
            final recent =
                transactions.length > 5
                    ? transactions.sublist(0, 5)
                    : transactions;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.white,
                  title: const Text('AFP'),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        monthName(now),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Opciones',
                      onSelected: (value) {
                        if (value == 'export') _exportBackup(context);
                        if (value == 'import') _importBackup(context);
                        if (value == 'about') _openAbout(context);
                        if (value == 'security') _openSecurity(context);
                        if (value == 'lock') _lockNow(context);
                      },
                      itemBuilder:
                          (_) => const [
                            PopupMenuItem(
                              value: 'export',
                              child: Text('Exportar respaldo'),
                            ),
                            PopupMenuItem(
                              value: 'import',
                              child: Text('Importar respaldo'),
                            ),
                            PopupMenuItem(
                              value: 'security',
                              child: Text('Seguridad'),
                            ),
                            PopupMenuItem(
                              value: 'lock',
                              child: Text('Bloquear ahora'),
                            ),
                            PopupMenuItem(
                              value: 'about',
                              child: Text('Acerca de'),
                            ),
                          ],
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
                    children: [
                      _BalanceSheet(
                        balance: balance,
                        income: income,
                        expense: expense,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            'Movimientos recientes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: onShowAll,
                            child: const Text('Ver todos'),
                          ),
                        ],
                      ),
                      if (transactions.isEmpty)
                        const _EmptyState()
                      else
                        Card(
                          child: Column(
                            children: [
                              for (final t in recent)
                                TransactionTile(
                                  transaction: t,
                                  onTap: () => _openEdit(context, t),
                                  onLongPress: () => _confirmDelete(context, t),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 72),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openEdit(BuildContext context, Transaction t) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddTransactionScreen(transaction: t)),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    final json = jsonEncode(
      FinanceRepository.instance.exportAll(),
    );
    final date = DateFormat('yyyy-MM-dd', 'es_MX').format(DateTime.now());
    try {
      await FileSaver.instance.saveFile(
        name: 'respaldo_afp_$date.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: MimeType.json,
        fileExtension: 'json',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respaldo exportado.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo exportar el respaldo.')),
        );
      }
    }
  }

  Future<void> _openAbout(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.savings_outlined,
              size: 40,
              color: seedColor,
            ),
            title: const Text('AFP'),
            content: FutureBuilder<String>(
              future: appVersionLabel(),
              builder: (context, snapshot) {
                final version = snapshot.data ?? 'v—';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Versión $version', textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      'Plataforma: ${platformLabel()}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tus datos se guardan solo en este dispositivo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  void _lockNow(BuildContext context) {
    final service = SecurityService.instance;
    if (!service.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activa el bloqueo con PIN en Seguridad.')),
      );
      return;
    }
    service.lock();
  }

  Future<void> _openSecurity(BuildContext context) {
    final service = SecurityService.instance;
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    String? localError;

    Future<void> finish(String message) async {
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final enabled = service.enabled;

          void validatePins() {
            final pin = next.text;
            if (pin.length < 4 || pin != confirm.text) {
              setDialogState(() {
                localError =
                    'El PIN debe tener al menos 4 dígitos y coincidir en ambos campos.';
              });
              return;
            }
            localError = null;
          }

          Widget pinField(TextEditingController c, String label) =>
              TextField(
                controller: c,
                obscureText: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: label),
              );

          return AlertDialog(
            title: const Text('Seguridad'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bloqueo con PIN'),
                    subtitle: const Text(
                      'Pide desbloqueo al abrir la app y al volver de segundo plano.',
                    ),
                    value: enabled,
                    onChanged: enabled
                        ? (on) async {
                            if (!service.unlock(current.text)) {
                              setDialogState(() {
                                localError = 'PIN actual incorrecto.';
                              });
                              return;
                            }
                            await service.disablePin();
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            await finish('Bloqueo desactivado.');
                          }
                        : (on) async {
                            final pin = next.text;
                            validatePins();
                            if (localError != null) return;
                            await service.enablePin(pin);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            await finish('Bloqueo activado.');
                          },
                  ),
                  const SizedBox(height: 4),
                  if (!enabled) ...[
                    pinField(next, 'Nuevo PIN'),
                    pinField(confirm, 'Repite el PIN'),
                  ] else ...[
                    pinField(current, 'PIN actual'),
                    pinField(next, 'PIN nuevo'),
                    pinField(confirm, 'Repite el PIN nuevo'),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          validatePins();
                          if (localError != null) return;
                          if (!service.unlock(current.text)) {
                            setDialogState(() {
                              localError = 'PIN actual incorrecto.';
                            });
                            return;
                          }
                          await service.enablePin(next.text);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          await finish('PIN actualizado.');
                        },
                        icon: const Icon(Icons.password),
                        label: const Text('Cambiar PIN'),
                      ),
                    ),
                  ],
                  if (localError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        localError!,
                        style: const TextStyle(
                          color: dangerColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FutureBuilder<bool>(
                    future: service.biometricsAvailable(),
                    builder: (context, snapshot) => Text(
                      snapshot.data == true
                          ? 'Tu dispositivo puede usar biometría (Face ID / huella / Windows Hello) para desbloquear más rápido.'
                          : 'La biometría no está disponible aquí (en Android/Windows sí); usa tu PIN.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      current.dispose();
      next.dispose();
      confirm.dispose();
    });
  }

  Future<void> _importBackup(BuildContext context) async {
    const group = XTypeGroup(label: 'JSON', extensions: ['json']);
    final XFile? file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El archivo seleccionado no es válido.')),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Importar respaldo'),
            content: const Text(
              'Se reemplazarán todos tus datos actuales por los del respaldo. '
              '¿Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Importar'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await FinanceRepository.instance.importAll(data);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respaldo importado correctamente.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar: ${e.toString().replaceAll('Exception: ', '')}'),
          ),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, Transaction t) {
    final repo = FinanceRepository.instance;
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Eliminar movimiento'),
            content: const Text('¿Seguro que deseas eliminar este movimiento?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: dangerColor),
                onPressed: () async {
                  await repo.deleteTransaction(t.id);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }
}

class _BalanceSheet extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;

  const _BalanceSheet({
    required this.balance,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: seedColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Balance total',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatMoney(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Ingresos del mes',
                amount: income,
                color: AppColors.income,
                icon: Icons.arrow_drop_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Gastos del mes',
                amount: expense,
                color: AppColors.expense,
                icon: Icons.arrow_drop_down,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatMoney(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: Colors.black26,
          ),
          SizedBox(height: 12),
          Text(
            'Aún no tienes movimientos.\n¡Agrega tu primer ingreso o gasto!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
