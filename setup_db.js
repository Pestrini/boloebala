const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const client = new Client({
  host: 'supabase.vps9867.panel.icontainer.net',
  port: 5432,
  user: 'postgres',
  password: 'b3xrtKmzyh4G48EM',
  database: 'postgres',
});

async function run() {
  try {
    await client.connect();
    console.log('Connected to PostgreSQL');
    
    // Ler o schema.sql que está na pasta raiz do projeto (agora movido para boloebala/supabase/schema.sql, pois o usuário moveu tudo)
    // O usuário disse: "eu apaguei a pasta projetoteste e movi o que estava dentro dela para a pasta boloebala"
    const schemaPath = path.join(__dirname, 'supabase', 'schema.sql');
    if (!fs.existsSync(schemaPath)) {
      throw new Error(`Arquivo não encontrado: ${schemaPath}`);
    }
    
    const sql = fs.readFileSync(schemaPath, 'utf8');
    
    console.log('Executando schema.sql...');
    await client.query(sql);
    console.log('Schema criado e seed executado com sucesso!');
  } catch (err) {
    console.error('Erro:', err);
  } finally {
    await client.end();
  }
}

run();
