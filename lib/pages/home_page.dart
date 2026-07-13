import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  // States
  bool _isPersonalizado = false;
  String _saborSelecionado = '';
  final TextEditingController _saborPersonalizadoController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _whatsAppController = TextEditingController();
  final TextEditingController _customColorController = TextEditingController();
  final TextEditingController _dataEntregaController = TextEditingController();

  final List<String> availableColors = ['Vermelho', 'Verde', 'Azul', 'Rosa', 'Roxo', 'Branco', 'Preto', 'Personalizada'];
  List<String> selectedColors = [];
  String customColor = "";
  
  bool _isSubmitting = false;

  final whatsappMask = MaskTextInputFormatter(
    mask: '(##) #####-####', 
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy
  );

  void toggleColor(String color) {
    setState(() {
      if (selectedColors.contains(color)) {
        selectedColors.remove(color);
      } else {
        if (selectedColors.length < 3) {
          selectedColors.add(color);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Você pode escolher no máximo 3 cores.')),
          );
        }
      }
    });
  }

  int get slicesPerColor {
    if (selectedColors.isEmpty) return 30;
    return 30 ~/ selectedColors.length;
  }

  Future<void> submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedColors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha pelo menos 1 cor de embrulho.')));
      return;
    }
    if (!_isPersonalizado && _saborSelecionado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha um sabor do cardápio.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final finalColors = selectedColors.map((c) => c == 'Personalizada' ? _customColorController.text : c).toList();
      
      final payload = {
        'origem': 'webapp',
        'cliente_nome': _nomeController.text,
        'cliente_whatsapp': _whatsAppController.text,
        'data_entrega': _dataEntregaController.text,
        'is_personalizado': _isPersonalizado,
        'sabor': _isPersonalizado ? _saborPersonalizadoController.text : _saborSelecionado,
        'detalhes_cores': finalColors,
      };

      // Inserção direta no Supabase para evitar CORS do n8n (e muito mais rápido)
      await supabase.from('pedidos').insert(payload);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pedido Recebido! 🎉'),
            content: const Text('A Tia Cida já recebeu seu pedido. Entraremos em contato pelo WhatsApp.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedColors.clear();
                    _nomeController.clear();
                    _whatsAppController.clear();
                    _dataEntregaController.clear();
                    _saborPersonalizadoController.clear();
                    _saborSelecionado = '';
                  });
                },
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar pedido: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Bolo & Bala', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.cake, size: 80, color: Colors.white54),
                    ),
                    Positioned(
                      top: 40,
                      right: 16,
                      child: IconButton(
                        icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                        tooltip: 'Painel da Tia Cida',
                        onPressed: () {
                          // Navegar para a página de admin (a ser implementada)
                          Navigator.pushNamed(context, '/admin');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dados do Cliente
                    const Text('Seus Dados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nomeController,
                      decoration: InputDecoration(labelText: 'Seu Nome', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (val) => val!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _whatsAppController,
                      inputFormatters: [whatsappMask],
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: 'WhatsApp', hintText: '(99) 99999-9999', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (val) => val!.length < 14 ? 'WhatsApp inválido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dataEntregaController,
                      decoration: InputDecoration(labelText: 'Data da Encomenda', hintText: 'Ex: 12/10 às 14h', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (val) => val!.isEmpty ? 'Por favor, informe quando precisa do bolo' : null,
                    ),
                    
                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Tipo de Pedido
                    const Text('Escolha seu Bolo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Bolo do Cardápio')),
                        ButtonSegment(value: true, label: Text('Bolo Personalizado')),
                      ],
                      selected: {_isPersonalizado},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          _isPersonalizado = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Lista de Produtos ou Campo Personalizado
                    _isPersonalizado 
                      ? TextFormField(
                          controller: _saborPersonalizadoController,
                          decoration: InputDecoration(
                            labelText: 'Qual sabor você deseja?',
                            hintText: 'Ex: Massa de nozes com doce de leite...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          maxLines: 3,
                          validator: (val) => _isPersonalizado && val!.isEmpty ? 'Descreva o sabor desejado' : null,
                        )
                      : FutureBuilder<List<Map<String, dynamic>>>(
                          future: supabase.from('produtos').select().eq('ativo', true).order('nome'),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                            if (snapshot.hasError) return Text('Erro ao carregar cardápio: ${snapshot.error}');
                            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('Nenhum produto disponível.');

                            final produtos = snapshot.data!;
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: produtos.length,
                              itemBuilder: (context, index) {
                                final p = produtos[index];
                                final isSelected = _saborSelecionado == p['nome'];
                                return Card(
                                  elevation: isSelected ? 4 : 1,
                                  color: isSelected ? Colors.pink.shade50 : null,
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(color: isSelected ? Colors.pink : Colors.transparent, width: 2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    title: Text(p['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(p['descricao'] ?? ''),
                                    trailing: Text('R\$ ${p['preco'].toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    onTap: () => setState(() => _saborSelecionado = p['nome']),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                    
                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Cores dos Embrulhos
                    const Text('Cores dos Embrulhos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text('O bolo rende 30 pedaços. Escolha até 3 cores e nós dividiremos igualmente!', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableColors.map((color) {
                        final isSelected = selectedColors.contains(color);
                        return FilterChip(
                          label: Text(color),
                          selected: isSelected,
                          selectedColor: Colors.pink.shade100,
                          checkmarkColor: Colors.pink,
                          onSelected: (selected) => toggleColor(color),
                        );
                      }).toList(),
                    ),
                    if (selectedColors.contains('Personalizada')) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _customColorController,
                        decoration: InputDecoration(
                          labelText: 'Qual cor personalizada?',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    ],

                    if (selectedColors.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.pink.shade200)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pie_chart, color: Colors.pink),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Divisão Matemática: Você escolheu ${selectedColors.length} cor(es). Serão $slicesPerColor fatias com cada cor.',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                    
                    // Botão Enviar
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                        ),
                        onPressed: _isSubmitting ? null : submitOrder,
                        child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('ENVIAR PEDIDO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
