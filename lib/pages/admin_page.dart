import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final supabase = Supabase.instance.client;

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
      default:
        return Colors.grey;
    }
  }

  Future<void> updateStatus(String id, String newStatus) async {
    try {
      await supabase.from('pedidos').update({'status': newStatus}).eq('id', id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pedido atualizado para $newStatus!')));
      setState(() {}); // Força recarregar a lista
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel da Tia Cida', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Pedidos',
            onPressed: () {
              setState(() {});
            },
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: supabase.from('pedidos').select().order('criado_em', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          final pedidos = snapshot.data ?? [];
          if (pedidos.isEmpty) {
            return const Center(child: Text('Nenhum pedido recebido ainda.', style: TextStyle(fontSize: 18)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final p = pedidos[index];
              final status = p['status'] ?? 'AGUARDANDO_ANALISE';
              final cores = p['detalhes_cores'] != null ? (p['detalhes_cores'] as List).join(', ') : 'Nenhuma';
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: getStatusColor(status), width: 2),
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Pedido #${p['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Chip(
                            label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: getStatusColor(status),
                          )
                        ],
                      ),
                      const Divider(),
                      Text('👤 Cliente: ${p['cliente_nome']}'),
                      Text('📱 WhatsApp: ${p['cliente_whatsapp']}'),
                      Text('📅 Data Desejada: ${p['data_entrega'] ?? 'Não informada'}'),
                      Text('🍰 Sabor: ${p['sabor']} ${p['is_personalizado'] == true ? "(Personalizado)" : ""}'),
                      Text('🎨 Cores: $cores'),
                      const SizedBox(height: 10),
                      if (p['comprovante_url'] != null)
                        TextButton.icon(
                          onPressed: () {
                            // Mostrar comprovante em um dialog
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Comprovante PIX'),
                                content: Image.network(p['comprovante_url']),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))]
                              )
                            );
                          },
                          icon: const Icon(Icons.receipt),
                          label: const Text('Ver Comprovante'),
                        ),
                      const SizedBox(height: 16),
                      // Ações
                      Wrap(
                        spacing: 8,
                        children: [
                          if (status == 'AGUARDANDO_ANALISE') ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => updateStatus(p['id'], 'APROVADO'),
                              icon: const Icon(Icons.check),
                              label: const Text('Aceitar'),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => updateStatus(p['id'], 'RECUSADO'),
                              icon: const Icon(Icons.close),
                              label: const Text('Recusar'),
                            ),
                          ],
                          if (status == 'APROVADO')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                              onPressed: () => updateStatus(p['id'], 'FINALIZADO'),
                              icon: const Icon(Icons.attach_money),
                              label: const Text('Marcar como Pago'),
                            ),
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
    );
  }
}
