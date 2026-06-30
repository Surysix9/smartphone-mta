-- Configurações do Servidor (Apenas Lado Servidor - Seguro contra vazamentos)
ConfigDB = {
    -- Tipo de Banco de Dados: "sqlite" ou "mysql"
    -- "sqlite": Cria um arquivo local na pasta do mod (ótimo para servidores pequenos ou testes).
    -- "mysql": Conecta a um servidor MySQL externo (melhor performance para servidores grandes).
    type = "sqlite", 
    
    -- Configurações se 'type = "mysql"'
    mysql = {
        host = "127.0.0.1", -- IP do servidor MySQL (geralmente localhost)
        user = "root",      -- Usuário do banco de dados
        pass = "",          -- Senha do banco de dados
        db = "mta_server",  -- Nome do banco de dados
        port = 3306         -- Porta do banco de dados
    },
    
    -- Configurações se 'type = "sqlite"'
    sqlite = {
        path = "database.db" -- Nome do arquivo local que será criado na pasta do script
    },
    
    -- Configurações de Integração (Para adaptar a qualquer Base/Servidor)
    integration = {
        elementDataID = "char:id",    -- Qual element data guarda o ID do jogador? (Padrão: "char:id")
        tableName = "characters",     -- Nome da tabela no banco de dados (Padrão: "characters")
        idColumn = "id",              -- Nome da coluna do ID (Padrão: "id")
        bankColumn = "bank",          -- Nome da coluna de saldo bancário (Padrão: "bank")
        nameColumn = "name",          -- Nome da coluna do primeiro nome (Padrão: "name")
        lastnameColumn = "lastname"   -- Nome da coluna do sobrenome (Padrão: "lastname")
    }
}
