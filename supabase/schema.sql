-- Drop existing tables if they exist
DROP TABLE IF EXISTS pedidos CASCADE;
DROP TABLE IF EXISTS produtos CASCADE;

-- Create produtos table
CREATE TABLE produtos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    descricao TEXT,
    preco DECIMAL(10,2) NOT NULL,
    ativo BOOLEAN DEFAULT true,
    categoria TEXT DEFAULT 'EMBRULHADO',
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create pedidos table
CREATE TABLE pedidos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    origem TEXT NOT NULL CHECK (origem IN ('whatsapp', 'webapp')),
    cliente_nome TEXT NOT NULL,
    cliente_whatsapp TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'AGUARDANDO_ANALISE' 
        CHECK (status IN ('AGUARDANDO_ANALISE', 'APROVADO', 'RECUSADO', 'FINALIZADO', 'CANCELADO', 'CANCELADO_PELO_CLIENTE')),
    is_personalizado BOOLEAN DEFAULT false,
    sabor TEXT,
    detalhes_cores JSONB NOT NULL DEFAULT '[]', -- Array of colors
    forma_pagamento TEXT CHECK (forma_pagamento IN ('PIX', 'DINHEIRO', 'CARTAO')),
    valor_total DECIMAL(10,2),
    data_entrega TEXT,
    metodo_entrega TEXT CHECK (metodo_entrega IN ('RETIRADA', 'ENTREGA')),
    endereco_entrega TEXT,
    valor_entrega DECIMAL(10,2),
    motivo_recusa TEXT,
    sugestao_recusa TEXT,
    comprovante_url TEXT,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- RLS Policies
ALTER TABLE produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos ENABLE ROW LEVEL SECURITY;

-- Create transacoes table
CREATE TABLE transacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo TEXT NOT NULL CHECK (tipo IN ('ENTRADA', 'SAIDA')),
    categoria TEXT,
    valor DECIMAL(10,2) NOT NULL,
    descricao TEXT,
    pedido_id UUID REFERENCES pedidos(id) ON DELETE SET NULL,
    data_transacao TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE transacoes ENABLE ROW LEVEL SECURITY;

-- Allow anonymous read access to active products
CREATE POLICY "Allow anonymous read on active produtos"
    ON produtos FOR SELECT
    TO public
    USING (ativo = true);

-- Allow admins full access to produtos
CREATE POLICY "Allow admin all access on produtos"
    ON produtos FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Allow anonymous insert into pedidos (webhook from PWA/n8n)
CREATE POLICY "Allow anonymous insert on pedidos"
    ON pedidos FOR INSERT
    TO public
    WITH CHECK (true);

-- Allow admins full access to pedidos
CREATE POLICY "Allow admin all access on pedidos"
    ON pedidos FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Allow admins full access to transacoes
CREATE POLICY "Allow admin all access on transacoes"
    ON transacoes FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Seed Produtos from Cardápio
INSERT INTO produtos (nome, descricao, preco) VALUES
('Chocolate c/ Brigadeiro', 'Massa de chocolate, recheio / cobertura brigadeiro.', 60.00),
('Pão de Mel', 'Massa de chocolate, cravo, canela, recheio doce de leite cob. brigadeiro e granulado.', 68.00),
('Prestígio', 'Massa de chocolate, recheio coco e cobertura de brigadeiro e granulado.', 65.00),
('Doce de leite + coco ou ameixa', 'Massa branca, caldo de doce de leite e leite de coco, cobertura doce de leite, creme de leite e coco ralado.', 65.00),
('Chocolate com nutella', 'Massa de chocolate, recheio / cobertura ganache de nutella.', 80.00),
('Nozes', 'Massa branca creme legere, recheio e cobertura nozes.', 75.00),
('Nozes doce de leite e coco', 'Massa branca recheio e cobertura creme legere e nozes.', 80.00),
('Leite ninho', 'Massa branca de leite ninho, cobertura de leites ninho e condensado.', 70.00),
('Leite ninho com abacaxi', 'Massa recheio e cobertura de leite ninho.', 75.00),
('Leite ninho com morango', 'Massa branca de leite ninho, cobertura de leites ninho e condensado.', 75.00),
('Frutas vermelha / Damasco', 'Massa branca recheio e cobertura de creme legere e geleia de frutas vermelha e damasco.', 75.00),
('Toalha felpuda', 'Bolo de coco banhado em calda de leite condensado e leite de coco envolvido com coco.', 60.00),
('Abacaxi com Coco', 'Massa branca recheada de creme legere e geleia de abacaxi envolvido com coco.', 75.00),
('Leite ninho com Nutella', 'Massa branca recheio ganache de nutella e cobertura de leite ninho.', 80.00),
('Brigadeiro c/ ninho 1 recheio', 'Massa chocolate, recheio de brigadeiro e ninho, cobertura ninho.', 75.00),
('Brigadeiro c/ ninho 2 recheios', 'Massa chocolate, recheio de brigadeiro e ninho, cobertura ninho.', 90.00);

-- --------------------------------------------------------
-- STORAGE SETUP (COMPROVANTES PIX)
-- --------------------------------------------------------
INSERT INTO storage.buckets (id, name, public) 
VALUES ('comprovantes', 'comprovantes', true) 
ON CONFLICT DO NOTHING;

-- Storage RLS Policies
CREATE POLICY "Allow anonymous insert comprovantes" 
ON storage.objects FOR INSERT TO public 
WITH CHECK (bucket_id = 'comprovantes');

CREATE POLICY "Allow public read comprovantes" 
ON storage.objects FOR SELECT TO public 
USING (bucket_id = 'comprovantes');
