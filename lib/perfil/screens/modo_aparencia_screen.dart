// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tema: apenas seletor claro/escuro (estado local).

import 'package:flutter/material.dart';

import '../widgets/mescla_subpage_scaffold.dart';

class ModoAparenciaScreen extends StatefulWidget {
  const ModoAparenciaScreen({super.key});

  @override
  State<ModoAparenciaScreen> createState() => _ModoAparenciaScreenState();
}

class _ModoAparenciaScreenState extends State<ModoAparenciaScreen> {
  int _selecionado = 0;

  @override
  Widget build(BuildContext context) {
    return MesclaSubpageScaffold(
      title: 'Modo de Aparência',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                RadioListTile<int>(
                  title: const Text('Claro'),
                  value: 0,
                  groupValue: _selecionado,
                  onChanged: (v) {
                    setState(() => _selecionado = v ?? 0);
                  },
                ),
                const Divider(height: 1),
                RadioListTile<int>(
                  title: const Text('Escuro'),
                  value: 1,
                  groupValue: _selecionado,
                  onChanged: (v) {
                    setState(() => _selecionado = v ?? 0);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
