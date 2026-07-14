import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';

class ClientAreaPage extends StatefulWidget {
  const ClientAreaPage({super.key});

  @override
  State<ClientAreaPage> createState() => _ClientAreaPageState();
}

class _ClientAreaPageState extends State<ClientAreaPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _whatsAppController = TextEditingController();
  
  final whatsappMask = MaskTextInputFormatter(
      mask: '(##) #####-####',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy);

  bool _isLoading = false;
  List<Map<String, dynamic>> _pedidos = [];
  bool _hasSearched = false;

  Future<void> fetchPedidos() async {
    if (_whatsAppController.text.length < 14) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite o WhatsApp completo.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('pedidos')
          .select()
          .eq('cliente_whatsapp', _whatsAppController.text)
          .order('criado_em', ascending: false);
      
      setState(() {
        _pedidos = List<Map<String, dynamic>>.from(response);
        _hasSearched = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar pedidos: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> updatePedidoPayment(String pedidoId, String formaPagamento, Uint8List? comprovanteBytes, String? comprovanteName) async {
    setState(() => _isLoading = true);
    try {
      String? comprovanteUrl;
      if (formaPagamento == 'PIX' && comprovanteBytes != null) {
        final ext = comprovanteName?.split('.').last ?? 'jpg';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_whatsAppController.text.replaceAll(RegExp(r'[^0-9]'), '')}.$ext';
        
        await supabase.storage.from('comprovantes').uploadBinary(
          fileName,
          comprovanteBytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );
        comprovanteUrl = supabase.storage.from('comprovantes').getPublicUrl(fileName);
      }

      await supabase.from('pedidos').update({
        'forma_pagamento': formaPagamento,
        if (comprovanteUrl != null) 'comprovante_url': comprovanteUrl,
      }).eq('id', pedidoId);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pagamento registrado com sucesso!')));
      await fetchPedidos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao registrar pagamento: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> openPaymentDialog(Map<String, dynamic> pedido) async {
    String? selectedForma;
    Uint8List? comprovanteBytes;
    String? comprovanteName;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Como deseja pagar?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total a pagar: R\$ ${pedido['valor_total']?.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    hint: const Text('Forma de Pagamento'),
                    value: selectedForma,
                    items: const [
                      DropdownMenuItem(value: 'PIX', child: Text('PIX (Enviar Comprovante)')),
                      DropdownMenuItem(value: 'DINHEIRO', child: Text('Dinheiro (Na entrega)')),
                      DropdownMenuItem(value: 'CARTAO', child: Text('Cartão (Na entrega)')),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedForma = val;
                      });
                    },
                  ),
                  if (selectedForma == 'PIX') ...[
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const SelectableText(
                        'Chave PIX (Celular):\n16991103825\nManuel de Oliveira Repas\nPagseguro',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: Text(comprovanteBytes == null ? 'Anexar Comprovante PIX' : 'Comprovante Selecionado'),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setDialogState(() {
                            comprovanteBytes = bytes;
                            comprovanteName = image.name;
                          });
                        }
                      },
                    )
                  ]
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: selectedForma == null || (selectedForma == 'PIX' && comprovanteBytes == null)
                      ? null
                      : () {
                          Navigator.pop(context);
                          updatePedidoPayment(pedido['id'], selectedForma!, comprovanteBytes, comprovanteName);
                        },
                  child: const Text('Confirmar Pagamento'),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> openRescheduleDialog(Map<String, dynamic> pedido) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 14, minute: 0),
      );
      if (time != null) {
        if (time.hour < 8 || time.hour > 18) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, escolha um horário entre 08:00 e 18:00.')));
          return;
        }
        
        final formattedDateTime = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}h';

        setState(() => _isLoading = true);
        try {
          await supabase.from('pedidos').update({
            'data_entrega': formattedDateTime,
            'status': 'AGUARDANDO_ANALISE',
            'motivo_recusa': null,
            'sugestao_recusa': null,
          }).eq('id', pedido['id']);

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido reagendado com sucesso!')));
          await fetchPedidos();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao reagendar: $e')));
        } finally {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> cancelOrder(String pedidoId) async {
    setState(() => _isLoading = true);
    try {
      await supabase.from('pedidos').update({
        'status': 'CANCELADO_PELO_CLIENTE',
      }).eq('id', pedidoId);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido cancelado com sucesso.')));
      await fetchPedidos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao cancelar: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'AGUARDANDO_ANALISE':
        color = Colors.orange;
        label = 'Em Análise';
        break;
      case 'APROVADO':
        color = Colors.green;
        label = 'Aprovado';
        break;
      case 'RECUSADO':
        color = Colors.red;
        label = 'Ajuste Necessário';
        break;
      case 'FINALIZADO':
        color = Colors.blue;
        label = 'Concluído';
        break;
      case 'CANCELADO':
      case 'CANCELADO_PELO_CLIENTE':
        color = Colors.red.shade900;
        label = 'Cancelado';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Área do Cliente'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_hasSearched && _whatsAppController.text.length >= 14) {
                fetchPedidos();
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Acompanhe seus pedidos informando seu WhatsApp.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _whatsAppController,
                    inputFormatters: [whatsappMask],
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'WhatsApp',
                      hintText: '(99) 99999-9999',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : fetchPedidos,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.search),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),
            if (_hasSearched && _pedidos.isEmpty && !_isLoading)
              const Expanded(child: Center(child: Text('Nenhum pedido encontrado para este número.')))
            else if (_pedidos.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _pedidos.length,
                  itemBuilder: (context, index) {
                    final pedido = _pedidos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(pedido['sabor'] ?? 'Bolo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                ),
                                buildStatusBadge(pedido['status']),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Data: ${pedido['data_entrega']}'),
                            Text('Entrega/Retirada: ${pedido['metodo_entrega'] ?? 'Não informado'}'),
                            if (pedido['valor_total'] != null)
                              Text('Total: R\$ ${pedido['valor_total'].toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            
                            if (pedido['forma_pagamento'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('Pago via: ${pedido['forma_pagamento']}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              ),

                            // AÇÕES DEPENDENDO DO STATUS
                            if (pedido['status'] == 'RECUSADO') ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Motivo: ${pedido['motivo_recusa'] ?? 'Sem justificativa'}', style: const TextStyle(color: Colors.red)),
                                    if (pedido['sugestao_recusa'] != null)
                                      Text('Sugestão da Cida: ${pedido['sugestao_recusa']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => openRescheduleDialog(pedido),
                                      icon: const Icon(Icons.calendar_month),
                                      label: const Text('Reagendar'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red.shade900),
                                      onPressed: () => cancelOrder(pedido['id']),
                                      icon: const Icon(Icons.cancel),
                                      label: const Text('Cancelar'),
                                    ),
                                  ),
                                ],
                              )
                            ],

                            if (pedido['status'] == 'APROVADO' && pedido['forma_pagamento'] == null) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  onPressed: () => openPaymentDialog(pedido),
                                  icon: const Icon(Icons.payment),
                                  label: const Text('Efetuar Pagamento / Combinar'),
                                ),
                              )
                            ]

                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
          ],
        ),
      ),
    );
  }
}
