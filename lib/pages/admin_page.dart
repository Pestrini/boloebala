import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final supabase = Supabase.instance.client;
  String _dashboardFilter = 'Tudo';
  DateTimeRange? _filterDateRangeDashboard;

  // Filtros de data para as abas de pedidos
  DateTimeRange? _filterDateRangePendentes;
  DateTimeRange? _filterDateRangeFinalizados;

  bool _filtroHojePendentes = false;
  bool _filtroHojeFinalizados = false;
  bool _filtroAguardandoAnalise = false;
  bool _filtroAguardandoPagamento = false;
  bool _filtroPagos = false;

  String _cardapioFilter = 'EMBRULHADO'; // 'EMBRULHADO' ou 'TRADICIONAL'

  Color getStatusColor(String status) {
    switch (status) {
      case 'AGUARDANDO_ANALISE':
        return Colors.orange;
      case 'APROVADO':
        return Colors.green;
      case 'RECUSADO':
        return Colors.red;
      case 'FINALIZADO':
        return Colors.blue;
      case 'CANCELADO':
      case 'CANCELADO_PELO_CLIENTE':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  Future<void> updateStatus(String id, String newStatus,
      {double? valorPersonalizado,
      double? valorEntrega,
      String? motivoRecusa,
      String? sugestaoRecusa,
      List<dynamic>? novasCores,
      Map<String, dynamic>? pedidoCompleto}) async {
    try {
      final Map<String, dynamic> updates = {'status': newStatus};
      if (valorPersonalizado != null)
        updates['valor_total'] = valorPersonalizado;
      if (valorEntrega != null) updates['valor_entrega'] = valorEntrega;
      if (motivoRecusa != null) updates['motivo_recusa'] = motivoRecusa;
      if (sugestaoRecusa != null) updates['sugestao_recusa'] = sugestaoRecusa;
      if (novasCores != null) updates['detalhes_cores'] = novasCores;

      await supabase.from('pedidos').update(updates).eq('id', id);

      // Automação: Se foi FINALIZADO, lança no Fluxo de Caixa (Transações)
      if (newStatus == 'FINALIZADO' && pedidoCompleto != null) {
        final cakeVal =
            valorPersonalizado ?? (pedidoCompleto['valor_total'] ?? 0.0);
        final deliveryVal =
            valorEntrega ?? (pedidoCompleto['valor_entrega'] ?? 0.0);
        final total = (cakeVal + deliveryVal).toDouble();

        if (total > 0) {
          await supabase.from('transacoes').insert({
            'tipo': 'ENTRADA',
            'categoria': 'Venda',
            'valor': total,
            'descricao':
                'Pedido #${pedidoCompleto['id'].toString().substring(0, 8)} - ${pedidoCompleto['cliente_nome']}',
            'pedido_id': id,
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pedido atualizado para $newStatus!')));
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e')));
    }
  }

  void _showAprovarDialog(Map<String, dynamic> pedido) {
    final bool needsCakePrice =
        pedido['is_personalizado'] == true && pedido['valor_total'] == null;
    final bool needsDeliveryFee = pedido['metodo_entrega'] == 'ENTREGA' &&
        pedido['valor_entrega'] == null;

    final standardColors = [
      'Vermelho',
      'Verde',
      'Azul',
      'Rosa',
      'Roxo',
      'Branco',
      'Preto'
    ];
    List<dynamic> coresList = List.from(pedido['detalhes_cores'] ?? []);
    String? customColor;
    int customColorIndex = -1;
    for (int i = 0; i < coresList.length; i++) {
      if (!standardColors.contains(coresList[i])) {
        customColor = coresList[i].toString();
        customColorIndex = i;
        break;
      }
    }
    final bool needsColorConfirm = customColor != null;

    if (!needsCakePrice && !needsDeliveryFee && !needsColorConfirm) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Aprovação'),
          content: const Text('Tem certeza que deseja aprovar este pedido?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Não')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                updateStatus(pedido['id'], 'APROVADO');
              },
              child: const Text('Sim, Aprovar'),
            )
          ],
        ),
      );
      return;
    }

    final cakeController = TextEditingController();
    final deliveryController = TextEditingController();
    final colorController = TextEditingController(text: customColor);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprovar Pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (needsColorConfirm) ...[
              Text(
                  'Cliente pediu a cor personalizada: $customColor. Você pode aceitar ou alterar para uma cor que você tenha (ex: Verde):'),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                    labelText: 'Cor Substituta (ou mantenha a pedida)'),
              ),
              const SizedBox(height: 10),
            ],
            if (needsCakePrice) ...[
              const Text('Defina o valor do bolo personalizado:'),
              TextField(
                controller: cakeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Valor Bolo (R\$)', prefixText: 'R\$ '),
              ),
              const SizedBox(height: 10),
            ],
            if (needsDeliveryFee) ...[
              const Text('Defina a taxa de entrega (Motoboy):'),
              Text('Endereço: ${pedido['endereco_entrega']}'),
              TextField(
                controller: deliveryController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Taxa Entrega (R\$)', prefixText: 'R\$ '),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              double? cakeVal;
              double? deliveryVal;

              if (needsCakePrice) {
                cakeVal =
                    double.tryParse(cakeController.text.replaceAll(',', '.'));
                if (cakeVal == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Valor do bolo inválido')));
                  return;
                }
              }
              if (needsDeliveryFee) {
                deliveryVal = double.tryParse(
                    deliveryController.text.replaceAll(',', '.'));
                if (deliveryVal == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Valor da entrega inválido')));
                  return;
                }
              }

              if (needsColorConfirm && colorController.text.isNotEmpty) {
                coresList[customColorIndex] = colorController.text;
              }

              Navigator.pop(context);
              updateStatus(pedido['id'], 'APROVADO',
                  valorPersonalizado: cakeVal,
                  valorEntrega: deliveryVal,
                  novasCores: needsColorConfirm ? coresList : null);
            },
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );
  }

  void _showRecusarDialog(Map<String, dynamic> pedido,
      {bool isCancel = false}) {
    final motivoController = TextEditingController();
    final sugestaoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCancel ? 'Cancelar Pedido' : 'Recusar Pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isCancel
                ? 'Qual a justificativa para cancelar este pedido?'
                : 'Informe ao cliente o motivo e dê uma sugestão (ex: reagendar para outro dia):'),
            const SizedBox(height: 10),
            TextField(
              controller: motivoController,
              decoration:
                  const InputDecoration(labelText: 'Motivo (Obrigatório)'),
            ),
            if (!isCancel) ...[
              const SizedBox(height: 10),
              TextField(
                controller: sugestaoController,
                decoration:
                    const InputDecoration(labelText: 'Sugestão (Opcional)'),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (motivoController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('O motivo é obrigatório.')));
                return;
              }
              Navigator.pop(context);
              updateStatus(pedido['id'], isCancel ? 'CANCELADO' : 'RECUSADO',
                  motivoRecusa: motivoController.text,
                  sugestaoRecusa: isCancel ? null : sugestaoController.text);
            },
            child:
                Text(isCancel ? 'Confirmar Cancelamento' : 'Confirmar Recusa'),
          ),
        ],
      ),
    );
  }

  void _showAdicionarTransacaoDialog() {
    final descController = TextEditingController();
    final valorController = TextEditingController();
    String tipo = 'SAIDA';

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nova Movimentação (Caixa)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: tipo,
                    items: const [
                      DropdownMenuItem(
                          value: 'SAIDA',
                          child: Text('Saída / Despesa / Retirada')),
                      DropdownMenuItem(
                          value: 'ENTRADA', child: Text('Entrada (Extra)')),
                    ],
                    onChanged: (val) => setDialogState(() => tipo = val!),
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                        labelText: 'Descrição (Ex: Compra de farinha)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: valorController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Valor (R\$)', prefixText: 'R\$ '),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    final valor = double.tryParse(
                        valorController.text.replaceAll(',', '.'));
                    if (valor == null || descController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Preencha os campos corretamente.')));
                      return;
                    }
                    try {
                      await supabase.from('transacoes').insert({
                        'tipo': tipo,
                        'categoria': 'Manual',
                        'valor': valor,
                        'descricao': descController.text,
                      });
                      Navigator.pop(context);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Movimentação salva!')));
                    } catch (e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Erro: $e')));
                    }
                  },
                  child: const Text('Salvar'),
                )
              ],
            );
          });
        });
  }

  void _showNovoProdutoDialog({Map<String, dynamic>? produtoEdit}) {
    final nomeController = TextEditingController(text: produtoEdit?['nome']);
    final descController =
        TextEditingController(text: produtoEdit?['descricao']);
    final precoController =
        TextEditingController(text: produtoEdit?['preco']?.toString());
    String categoria = produtoEdit?['categoria'] ?? _cardapioFilter;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title:
                  Text(produtoEdit == null ? 'Novo Produto' : 'Editar Produto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: categoria,
                      items: const [
                        DropdownMenuItem(
                            value: 'EMBRULHADO',
                            child: Text('Bolo Embrulhado')),
                        DropdownMenuItem(
                            value: 'TRADICIONAL',
                            child: Text('Bolo Tradicional')),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => categoria = val!),
                      decoration: const InputDecoration(labelText: 'Categoria'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nomeController,
                      decoration:
                          const InputDecoration(labelText: 'Nome do Sabor'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                          labelText: 'Descrição / Recheio'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: precoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Preço (R\$)', prefixText: 'R\$ '),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    final preco = double.tryParse(
                        precoController.text.replaceAll(',', '.'));
                    if (preco == null || nomeController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Preencha os campos corretamente.')));
                      return;
                    }
                    try {
                      if (produtoEdit == null) {
                        await supabase.from('produtos').insert({
                          'nome': nomeController.text,
                          'descricao': descController.text,
                          'preco': preco,
                          'categoria': categoria,
                          'ativo': true,
                        });
                      } else {
                        await supabase.from('produtos').update({
                          'nome': nomeController.text,
                          'descricao': descController.text,
                          'preco': preco,
                          'categoria': categoria,
                        }).eq('id', produtoEdit['id']);
                      }
                      Navigator.pop(context);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Produto salvo!')));
                    } catch (e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Erro: $e')));
                    }
                  },
                  child: const Text('Salvar'),
                )
              ],
            );
          });
        });
  }

  Widget _buildDashboard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchDashboardData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
              child: Text('Erro ao carregar dashboard: ${snapshot.error}'));

        final transacoes = snapshot.data ?? [];
        double entradas = 0;
        double saidas = 0;

        // Extract dates and values for the chart
        final Map<String, double> chartDataEntradas = {};
        final Map<String, double> chartDataSaidas = {};

        for (var t in transacoes) {
          final valor = (t['valor'] ?? 0).toDouble();
          final tipo = t['tipo'];
          if (tipo == 'ENTRADA') entradas += valor;
          if (tipo == 'SAIDA') saidas += valor;

          final rawDate = t['data_transacao'] ?? '';
          if (rawDate.toString().isNotEmpty) {
            try {
              final date = DateTime.parse(rawDate.toString());
              final dayKey = DateFormat('dd/MM').format(date);
              if (tipo == 'ENTRADA') {
                chartDataEntradas[dayKey] =
                    (chartDataEntradas[dayKey] ?? 0) + valor;
              } else {
                chartDataSaidas[dayKey] =
                    (chartDataSaidas[dayKey] ?? 0) + valor;
              }
            } catch (_) {}
          }
        }

        final saldo = entradas - saidas;

        final allDatesSet = <String>{
          ...chartDataEntradas.keys,
          ...chartDataSaidas.keys
        };
        final sortedDates = allDatesSet.toList()
          ..sort((a, b) {
            try {
              final da = DateFormat('dd/MM').parse(a);
              final db = DateFormat('dd/MM').parse(b);
              return da.compareTo(db);
            } catch (e) {
              return 0;
            }
          });

        final spotsEntradas = <FlSpot>[];
        final spotsSaidas = <FlSpot>[];
        for (int i = 0; i < sortedDates.length; i++) {
          spotsEntradas.add(
              FlSpot(i.toDouble(), chartDataEntradas[sortedDates[i]] ?? 0));
          spotsSaidas
              .add(FlSpot(i.toDouble(), chartDataSaidas[sortedDates[i]] ?? 0));
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Filtro de Período:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _dashboardFilter,
                    items: const [
                      DropdownMenuItem(
                          value: 'Tudo', child: Text('Todo o Período')),
                      DropdownMenuItem(
                          value: 'Mês Atual', child: Text('Mês Atual')),
                      DropdownMenuItem(
                          value: 'Últimos 7 dias',
                          child: Text('Últimos 7 dias')),
                      DropdownMenuItem(
                          value: 'Personalizado', child: Text('Personalizado')),
                    ],
                    onChanged: (val) async {
                      if (val == 'Personalizado') {
                        final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2100));
                        if (range != null) {
                          setState(() {
                            _filterDateRangeDashboard = range;
                            _dashboardFilter = val!;
                          });
                        }
                      } else if (val != null) {
                        setState(() {
                          _dashboardFilter = val;
                          _filterDateRangeDashboard = null;
                        });
                      }
                    },
                  ),
                  if (_dashboardFilter == 'Personalizado' &&
                      _filterDateRangeDashboard != null)
                    Text(
                        '(${DateFormat('dd/MM/yy').format(_filterDateRangeDashboard!.start)} - ${DateFormat('dd/MM/yy').format(_filterDateRangeDashboard!.end)})',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () => _baixarExtrato(transacoes),
                    icon: const Icon(Icons.download),
                    label: const Text('Baixar Extrato (CSV)'),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: _buildDashCard(
                          'Entradas',
                          'R\$ ${entradas.toStringAsFixed(2)}',
                          Colors.green,
                          'Vendas')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildDashCard(
                          'Saídas',
                          'R\$ ${saidas.toStringAsFixed(2)}',
                          Colors.red,
                          'Despesas')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildDashCard(
                          'Saldo',
                          'R\$ ${saldo.toStringAsFixed(2)}',
                          saldo >= 0 ? Colors.blue : Colors.deepOrange,
                          'Caixa')),
                ],
              ),
              const SizedBox(height: 20),
              if (sortedDates.length > 1) ...[
                const Text('Evolução do Caixa',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SizedBox(
                    height: 200,
                    child: LineChart(LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < sortedDates.length) {
                                    return Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        child: Text(sortedDates[value.toInt()],
                                            style:
                                                const TextStyle(fontSize: 10)));
                                  }
                                  return const Text('');
                                })),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade300)),
                      lineBarsData: [
                        LineChartBarData(
                            spots: spotsEntradas,
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 3,
                            dotData: const FlDotData(show: false)),
                        LineChartBarData(
                            spots: spotsSaidas,
                            isCurved: true,
                            color: Colors.red,
                            barWidth: 3,
                            dotData: const FlDotData(show: false)),
                      ],
                    ))),
                const SizedBox(height: 20),
              ],
              const Text('Extrato Detalhado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                  child: transacoes.isEmpty
                      ? const Center(
                          child: Text('Nenhuma transação no período.'))
                      : ListView.builder(
                          itemCount: transacoes.length,
                          itemBuilder: (context, index) {
                            final t = transacoes[index];
                            final isEntrada = t['tipo'] == 'ENTRADA';
                            DateTime? dataT;
                            try {
                              dataT = DateTime.parse(t['data_transacao']);
                            } catch (_) {}

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isEntrada
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                child: Icon(
                                    isEntrada
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color:
                                        isEntrada ? Colors.green : Colors.red),
                              ),
                              title: Text(t['descricao'] ?? 'Sem descrição'),
                              subtitle: Text(dataT != null
                                  ? DateFormat('dd/MM/yyyy HH:mm').format(dataT)
                                  : ''),
                              trailing: Text(
                                  '${isEntrada ? "+" : "-"} R\$ ${(t['valor'] ?? 0).toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color:
                                          isEntrada ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            );
                          })),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16)),
                  onPressed: _showAdicionarTransacaoDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova Movimentação',
                      style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _baixarExtrato(List<dynamic> transacoes) async {
    List<List<dynamic>> rows = [];
    rows.add(["Data", "Tipo", "Categoria", "Descricao", "Valor", "Pedido ID"]);
    for (var t in transacoes) {
      DateTime? d;
      try {
        d = DateTime.parse(t['data_transacao']);
      } catch (_) {}

      rows.add([
        d != null ? DateFormat('dd/MM/yyyy HH:mm').format(d) : '',
        t['tipo'] ?? '',
        t['categoria'] ?? '',
        t['descricao'] ?? '',
        t['valor']?.toString() ?? '0',
        t['pedido_id'] ?? ''
      ]);
    }
    String csvStr = Csv().encode(rows);
    final bytes = utf8.encode(csvStr);
    try {
      await FileSaver.instance.saveFile(
        name: 'extrato_${DateTime.now().millisecondsSinceEpoch}.csv',
        bytes: Uint8List.fromList(bytes),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Extrato baixado com sucesso!')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar arquivo: $e')));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDashboardData() async {
    var query = supabase.from('transacoes').select();
    if (_dashboardFilter == 'Últimos 7 dias') {
      final date = DateTime.now().subtract(const Duration(days: 7));
      query = query.gte('data_transacao', date.toIso8601String());
    } else if (_dashboardFilter == 'Mês Atual') {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month, 1);
      query = query.gte('data_transacao', date.toIso8601String());
    } else if (_dashboardFilter == 'Personalizado' &&
        _filterDateRangeDashboard != null) {
      query = query
          .gte('data_transacao',
              _filterDateRangeDashboard!.start.toIso8601String())
          .lte(
              'data_transacao',
              _filterDateRangeDashboard!.end
                  .add(const Duration(days: 1))
                  .toIso8601String());
    }
    return await query.order('data_transacao', ascending: false);
  }

  Widget _buildDashCard(
      String title, String value, Color color, String subtitle) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: color, width: 2),
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 24)),
            const SizedBox(height: 10),
            Text(subtitle,
                style: TextStyle(color: color.withOpacity(0.8)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidosTab(List<String> statusFiltros, bool isHistorico) {
    return Column(
      children: [
        Container(
          color: const Color(0xFFFCF9F2),
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Filtros:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((isHistorico
                          ? _filterDateRangeFinalizados
                          : _filterDateRangePendentes) !=
                      null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: () => setState(() {
                        if (isHistorico)
                          _filterDateRangeFinalizados = null;
                        else
                          _filterDateRangePendentes = null;
                      }),
                    ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text((isHistorico
                                ? _filterDateRangeFinalizados
                                : _filterDateRangePendentes) !=
                            null
                        ? '${(isHistorico ? _filterDateRangeFinalizados : _filterDateRangePendentes)!.start.day}/${(isHistorico ? _filterDateRangeFinalizados : _filterDateRangePendentes)!.start.month} até ${(isHistorico ? _filterDateRangeFinalizados : _filterDateRangePendentes)!.end.day}/${(isHistorico ? _filterDateRangeFinalizados : _filterDateRangePendentes)!.end.month}'
                        : 'Filtrar Período'),
                    onPressed: () async {
                      final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2100));
                      if (range != null) {
                        setState(() {
                          if (isHistorico)
                            _filterDateRangeFinalizados = range;
                          else
                            _filterDateRangePendentes = range;
                        });
                      }
                    },
                  ),
                ],
              ),
              FilterChip(
                label: const Text('Pedidos de Hoje'),
                selected:
                    isHistorico ? _filtroHojeFinalizados : _filtroHojePendentes,
                onSelected: (val) {
                  setState(() {
                    if (isHistorico)
                      _filtroHojeFinalizados = val;
                    else
                      _filtroHojePendentes = val;
                  });
                },
                selectedColor: const Color(0xFFF9F1D8),
              ),
              if (!isHistorico)
                FilterChip(
                  label: const Text('Aguardando Análise'),
                  selected: _filtroAguardandoAnalise,
                  onSelected: (val) {
                    setState(() {
                      _filtroAguardandoAnalise = val;
                    });
                  },
                  selectedColor: Colors.orange.shade300,
                ),
              if (!isHistorico)
                FilterChip(
                  label: const Text('Aguardando Pagamento'),
                  selected: _filtroAguardandoPagamento,
                  onSelected: (val) {
                    setState(() {
                      _filtroAguardandoPagamento = val;
                    });
                  },
                  selectedColor: Colors.yellow.shade300,
                ),
              if (!isHistorico)
                FilterChip(
                  label: const Text('Pagos'),
                  selected: _filtroPagos,
                  onSelected: (val) {
                    setState(() {
                      _filtroPagos = val;
                    });
                  },
                  selectedColor: Colors.green.shade300,
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: () async {
              var query = supabase
                  .from('pedidos')
                  .select()
                  .inFilter('status', statusFiltros);
              final rangeFilter = isHistorico
                  ? _filterDateRangeFinalizados
                  : _filterDateRangePendentes;

              if (!isHistorico && _filtroAguardandoAnalise) {
                query = query.eq('status', 'AGUARDANDO_ANALISE');
              }
              if (!isHistorico && _filtroAguardandoPagamento) {
                query = query.eq('is_pago', false);
              }
              if (!isHistorico && _filtroPagos) {
                query = query.eq('is_pago', true);
              }

              var result = await query.order('criado_em', ascending: false);

              if (rangeFilter != null ||
                  (isHistorico
                      ? _filtroHojeFinalizados
                      : _filtroHojePendentes)) {
                result = result.where((p) {
                  if (p['data_entrega'] == null) return false;
                  try {
                    final parts = p['data_entrega']
                        .toString()
                        .split(' às ')[0]
                        .split('/');
                    final date = DateTime(int.parse(parts[2]),
                        int.parse(parts[1]), int.parse(parts[0]));

                    bool passesRange = true;
                    if (rangeFilter != null) {
                      passesRange = date.isAfter(rangeFilter.start
                              .subtract(const Duration(days: 1))) &&
                          date.isBefore(
                              rangeFilter.end.add(const Duration(days: 1)));
                    }

                    bool passesHoje = true;
                    if (isHistorico
                        ? _filtroHojeFinalizados
                        : _filtroHojePendentes) {
                      final hoje = DateTime.now();
                      passesHoje = date.year == hoje.year &&
                          date.month == hoje.month &&
                          date.day == hoje.day;
                    }

                    return passesRange && passesHoje;
                  } catch (e) {
                    return false;
                  }
                }).toList();
              }
              return result;
            }(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(child: Text('Erro: ${snapshot.error}'));
              final pedidos = snapshot.data ?? [];
              if (pedidos.isEmpty)
                return const Center(
                    child: Text('Nenhum pedido encontrado.',
                        style: TextStyle(fontSize: 18)));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pedidos.length,
                itemBuilder: (context, index) {
                  final p = pedidos[index];
                  final status = p['status'] ?? 'AGUARDANDO_ANALISE';
                  final cores = p['detalhes_cores'] != null
                      ? (p['detalhes_cores'] as List).join(', ')
                      : 'Nenhuma';

                  final double boloVal = (p['valor_total'] ?? 0).toDouble();
                  final double freteVal = (p['valor_entrega'] ?? 0).toDouble();
                  final double totalVal = boloVal + freteVal;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                        side:
                            BorderSide(color: getStatusColor(status), width: 2),
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  'Pedido #${p['id'].toString().substring(0, 8)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Chip(
                                label: Text(
                                    status == 'APROVADO'
                                        ? (p['is_pago'] == true
                                            ? 'PAGO ✅'
                                            : 'AGUARDANDO PAGAMENTO')
                                        : status,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                backgroundColor: getStatusColor(status),
                              )
                            ],
                          ),
                          const Divider(),
                          Text('👤 Cliente: ${p['cliente_nome']}'),
                          Row(
                            children: [
                              Text('📱 WhatsApp: ${p['cliente_whatsapp']}'),
                              IconButton(
                                icon:
                                    const Icon(Icons.chat, color: Colors.green),
                                tooltip: 'Conversar com Cliente',
                                onPressed: () async {
                                  final numStr = p['cliente_whatsapp']
                                      .toString()
                                      .replaceAll(RegExp(r'\D'), '');
                                  if (numStr.isNotEmpty) {
                                    final url = Uri.parse(
                                        'https://wa.me/55$numStr?text=Olá ${p['cliente_nome']}, sou a Tia Cida, sobre o seu pedido #${p['id'].toString().substring(0, 8)}...');
                                    if (await canLaunchUrl(url))
                                      await launchUrl(url);
                                  }
                                },
                              )
                            ],
                          ),
                          Text(
                              '📅 Data Desejada: ${p['data_entrega'] ?? 'Não informada'}'),
                          Text(
                              '🍰 Sabor: ${p['sabor']} ${p['is_personalizado'] == true ? "(Personalizado)" : ""}'),
                          Text('🎨 Cores: $cores'),
                          const SizedBox(height: 5),
                          Text('🚚 Tipo: ${p['metodo_entrega'] ?? 'RETIRADA'}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (p['metodo_entrega'] == 'ENTREGA' &&
                              p['endereco_entrega'] != null)
                            Text('📍 Endereço: ${p['endereco_entrega']}'),
                          const Divider(),
                          if (boloVal > 0)
                            Text('Bolo: R\$ ${boloVal.toStringAsFixed(2)}'),
                          if (freteVal > 0)
                            Text('Frete: R\$ ${freteVal.toStringAsFixed(2)}'),
                          if (totalVal > 0)
                            Text(
                                'Total a Receber: R\$ ${totalVal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          if (p['forma_pagamento'] != null)
                            Text(
                                '💳 Pagamento do Cliente: ${p['forma_pagamento']}',
                                style: const TextStyle(color: Colors.blue)),
                          if (status == 'RECUSADO' ||
                              status == 'CANCELADO') ...[
                            const SizedBox(height: 5),
                            Text('❌ Motivo: ${p['motivo_recusa']}'),
                          ],
                          const SizedBox(height: 10),
                          if (p['comprovante_url'] != null)
                            TextButton.icon(
                              onPressed: () {
                                showDialog(
                                    context: context,
                                    builder: (_) =>
                                        AlertDialog(
                                            title:
                                                const Text('Comprovante PIX'),
                                            content: Image.network(
                                                p['comprovante_url']),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('Fechar'))
                                            ]));
                              },
                              icon: const Icon(Icons.receipt),
                              label: const Text('Ver Comprovante PIX'),
                            ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (status == 'AGUARDANDO_ANALISE') ...[
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white),
                                    onPressed: () => _showAprovarDialog(p),
                                    child: const Text('Aprovar')),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white),
                                    onPressed: () => _showRecusarDialog(p),
                                    child: const Text('Recusar')),
                              ],
                              if (status == 'APROVADO') ...[
                                if (p['is_pago'] != true)
                                  ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white),
                                      onPressed: () async {
                                        await supabase.from('pedidos').update({
                                          'is_pago': true
                                        }).eq('id', p['id']);
                                        setState(() {});
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Marcado como Pago! ✅')));
                                        }
                                      },
                                      child: const Text('Marcar como Pago')),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white),
                                    onPressed: () {
                                      showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Marcar como Concluído'),
                                                content: const Text(
                                                    'Tem certeza que este pedido foi concluído e finalizado? O valor será lançado no Caixa.'),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child: const Text('Não')),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      updateStatus(
                                                          p['id'], 'FINALIZADO',
                                                          pedidoCompleto: p);
                                                    },
                                                    child: const Text(
                                                        'Sim, Concluir'),
                                                  )
                                                ],
                                              ));
                                    },
                                    child: const Text('Marcar Concluído')),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade900,

                                        foregroundColor: Colors.white),
                                    onPressed: () =>
                                        _showRecusarDialog(p, isCancel: true),
                                    child: const Text('Cancelar Pedido')),
                              ]
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProdutosTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'EMBRULHADO', label: Text('Embrulhados')),
              ButtonSegment(value: 'TRADICIONAL', label: Text('Tradicionais')),
            ],
            selected: {_cardapioFilter},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => _cardapioFilter = newSelection.first);
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('produtos')
                .select()
                .eq('categoria', _cardapioFilter)
                .order('nome'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(child: Text('Erro: ${snapshot.error}'));
              final produtos = snapshot.data ?? [];

              return Scaffold(
                body: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: produtos.length,
                  itemBuilder: (context, index) {
                    final p = produtos[index];
                    final ativo = p['ativo'] == true;
                    return Card(
                      child: ListTile(
                        title: Text(p['nome'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'R\$ ${p['preco'].toStringAsFixed(2)} - ${p['descricao'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showNovoProdutoDialog(produtoEdit: p),
                            ),
                            Switch(
                              value: ativo,
                              onChanged: (val) async {
                                await supabase
                                    .from('produtos')
                                    .update({'ativo': val}).eq('id', p['id']);
                                setState(() {});
                              },
                              activeColor: const Color(0xFFD4AF37),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => _showNovoProdutoDialog(),
                  backgroundColor: const Color(0xFFD4AF37),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset('assets/images/logo.png', height: 40),
              const SizedBox(width: 10),
              const Text('Painel da Tia Cida'),
            ],
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFD4AF37),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {}),
            )
          ],
          bottom: const TabBar(
            labelColor: Color(0xFFD4AF37),
            unselectedLabelColor: Colors.black54,
            indicatorColor: Color(0xFFD4AF37),
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Pendentes'),
              Tab(icon: Icon(Icons.history), text: 'Finalizados'),
              Tab(icon: Icon(Icons.attach_money), text: 'Caixa'),
              Tab(icon: Icon(Icons.cake), text: 'Cardápio'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPedidosTab(['AGUARDANDO_ANALISE', 'APROVADO'], false),
            _buildPedidosTab([
              'FINALIZADO',
              'RECUSADO',
              'CANCELADO',
              'CANCELADO_PELO_CLIENTE'
            ], true),
            _buildDashboard(),
            _buildProdutosTab(),
          ],
        ),
      ),
    );
  }
}
