import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // States
  String _tipoBolo = 'EMBRULHADO'; // EMBRULHADO, TRADICIONAL, PERSONALIZADO
  String _saborSelecionado = '';
  final TextEditingController _saborPersonalizadoController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _whatsAppController = TextEditingController();
  final TextEditingController _customColorController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();

  DateTime? _dataEscolhida;
  TimeOfDay? _horaEscolhida;

  String? _metodoEntrega;

  final List<String> availableColors = [
    'Vermelho', 'Verde', 'Azul', 'Rosa', 'Roxo', 'Branco', 'Preto', 'Personalizada'
  ];
  List<String> selectedColors = [];
  String customColor = "";
  
  double? _precoSelecionado;

  bool _isSubmitting = false;

  final whatsappMask = MaskTextInputFormatter(
      mask: '(##) #####-####',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy);

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

  Future<void> _pickDateTime() async {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, escolha um horário entre 08:00 e 18:00.')),
          );
          return;
        }
        setState(() {
          _dataEscolhida = date;
          _horaEscolhida = time;
        });
      }
    }
  }

  String get formattedDateTime {
    if (_dataEscolhida == null || _horaEscolhida == null) return '';
    final d = _dataEscolhida!;
    final t = _horaEscolhida!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} às ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}h';
  }

  Future<void> submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoBolo == 'EMBRULHADO' && selectedColors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha pelo menos 1 cor de embrulho.')));
      return;
    }
    if (_tipoBolo != 'PERSONALIZADO' && _saborSelecionado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha um sabor do cardápio.')));
      return;
    }
    if (_dataEscolhida == null || _horaEscolhida == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha a data e hora.')));
      return;
    }
    if (_metodoEntrega == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha Entrega ou Retirada.')));
      return;
    }
    if (_metodoEntrega == 'ENTREGA' && _enderecoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o endereço de entrega.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final finalColors = selectedColors
          .map((c) => c == 'Personalizada' ? _customColorController.text : c)
          .toList();

      final payload = {
        'origem': 'webapp',
        'cliente_nome': _nomeController.text,
        'cliente_whatsapp': _whatsAppController.text,
        'data_entrega': formattedDateTime,
        'is_personalizado': _tipoBolo == 'PERSONALIZADO',
        'sabor': _tipoBolo == 'PERSONALIZADO' ? _saborPersonalizadoController.text : _saborSelecionado,
        'detalhes_cores': _tipoBolo == 'EMBRULHADO' ? finalColors : [],
        'metodo_entrega': _metodoEntrega,
        'endereco_entrega': _metodoEntrega == 'ENTREGA' ? _enderecoController.text : null,
        if (_tipoBolo != 'PERSONALIZADO' && _precoSelecionado != null) 'valor_total': _precoSelecionado,
      };

      await supabase.from('pedidos').insert(payload);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pedido Enviado! 🎉'),
            content: const Text('A Tia Cida vai analisar seu pedido e definir o valor. Acompanhe o status na Área do Cliente!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedColors.clear();
                    _nomeController.clear();
                    _whatsAppController.clear();
                    _saborPersonalizadoController.clear();
                    _enderecoController.clear();
                    _saborSelecionado = '';
                    _precoSelecionado = null;
                    _dataEscolhida = null;
                    _horaEscolhida = null;
                    _metodoEntrega = null;
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
              title: const Text('Bolo & Bala',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
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
                    const Center(child: Icon(Icons.cake, size: 80, color: Colors.white54)),
                    Positioned(
                      top: 40,
                      right: 16,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.person, color: Colors.white),
                            tooltip: 'Meus Pedidos',
                            onPressed: () => Navigator.pushNamed(context, '/client'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                            tooltip: 'Painel da Tia Cida',
                            onPressed: () => Navigator.pushNamed(context, '/admin'),
                          ),
                        ],
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
                    InkWell(
                      onTap: _pickDateTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Data e Hora da Entrega',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          formattedDateTime.isEmpty ? 'Toque para selecionar' : formattedDateTime,
                          style: TextStyle(color: formattedDateTime.isEmpty ? Colors.grey.shade600 : Colors.black, fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 10),

                    const Text('Escolha seu Bolo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'EMBRULHADO', label: Text('Embrulhado')),
                        ButtonSegment(value: 'TRADICIONAL', label: Text('Tradicional')),
                        ButtonSegment(value: 'PERSONALIZADO', label: Text('Personalizado')),
                      ],
                      selected: {_tipoBolo},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _tipoBolo = newSelection.first;
                          _saborSelecionado = '';
                          _precoSelecionado = null;
                          selectedColors.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    _tipoBolo == 'PERSONALIZADO'
                        ? TextFormField(
                            controller: _saborPersonalizadoController,
                            decoration: InputDecoration(labelText: 'Qual sabor você deseja?', hintText: 'Ex: Massa de nozes com doce de leite...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            maxLines: 3,
                            validator: (val) => _tipoBolo == 'PERSONALIZADO' && val!.isEmpty ? 'Descreva o sabor desejado' : null,
                          )
                        : FutureBuilder<List<Map<String, dynamic>>>(
                            future: supabase.from('produtos').select().eq('ativo', true).eq('categoria', _tipoBolo).order('nome'),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                              if (snapshot.hasError) return Text('Erro ao carregar cardápio: ${snapshot.error}');
                              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('Nenhum produto disponível nesta categoria.');

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
                                      onTap: () => setState(() {
                                        _saborSelecionado = p['nome'];
                                        _precoSelecionado = p['preco'].toDouble();
                                      }),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                    if (_tipoBolo == 'EMBRULHADO') ...[
                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 10),

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
                          decoration: InputDecoration(labelText: 'Qual cor personalizada?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        )
                      ],

                      if (selectedColors.isNotEmpty) ...[
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.pink.shade200)),
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
                    ],

                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 10),

                    const Text('Entrega ou Retirada?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'RETIRADA', label: Text('Vou Retirar')),
                        ButtonSegment(value: 'ENTREGA', label: Text('Quero Entrega')),
                      ],
                      selected: {_metodoEntrega ?? 'RETIRADA'},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() => _metodoEntrega = newSelection.first);
                      },
                    ),
                    const SizedBox(height: 15),
                    
                    if (_metodoEntrega == 'RETIRADA' || _metodoEntrega == null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          children: [
                            Icon(Icons.store, color: Colors.grey),
                            SizedBox(width: 10),
                            Expanded(child: Text('Rua Vital Brasil, 1123\nVila Virginia - Ribeirão Preto-SP', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                    
                    if (_metodoEntrega == 'ENTREGA')
                      TextFormField(
                        controller: _enderecoController,
                        decoration: InputDecoration(
                          labelText: 'Seu Endereço Completo',
                          hintText: 'Rua, Número, Bairro, Ponto de Referência',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        maxLines: 2,
                      ),

                    const SizedBox(height: 40),

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
