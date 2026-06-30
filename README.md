# Smartphone MTA

![Lua](https://img.shields.io/badge/Lua-2C2D72?style=for-the-badge&logo=lua&logoColor=white)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![CSS3](https://img.shields.io/badge/CSS3-1572B6?style=for-the-badge&logo=css3&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)
![MySQL](https://img.shields.io/badge/MySQL-00000F?style=for-the-badge&logo=mysql&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white)

Sistema de Smartphone totalmente open source e com atualizações constantes para servidores de Multi Theft Auto (MTA:SA).

## 📸 Demonstração

Aqui estão algumas imagens do sistema em funcionamento:

| Tela Inicial | Menu do Banco | Transferência / Pix | Notificações |
| :---: | :---: | :---: | :---: |
| <img src="prints/home.png" width="220"> | <img src="prints/bank.png" width="220"> | <img src="prints/bank2.png" width="220"> | <img src="prints/swipernotifications.png" width="220"> |

## ⚙️ Como Instalar e Configurar

Siga os passos abaixo para fazer o sistema funcionar corretamente no seu servidor:

1. **Baixe e extraia** os arquivos do repositório para a pasta de recursos (`resources`) do seu servidor.
2. Certifique-se de ter as pastas `pAttach` e `phone` nos seus recursos.
3. Inicie os resources no console do MTA ou adicione ao seu `mtaserver.conf` para iniciar automaticamente:
   ```xml
   <resource src="pAttach" startup="1" protected="0" />
   <resource src="phone" startup="1" protected="0" />
   ```

### ⚠️ Requisito Importante: pAttach
É **obrigatório** iniciar o resource `pAttach` para o perfeito funcionamento deste script. O sistema de smartphone utiliza o `pAttach` para anexar de forma correta e otimizada o objeto 3D do celular na mão do jogador durante as animações de uso. Se o `pAttach` não estiver rodando, o celular não aparecerá fisicamente na mão do personagem.

### ⚙️ Arquivos de Configuração (NOVO!)

O sistema foi atualizado para ser **100% independente** (Standalone), sem precisar de outros mods base. Foram adicionados dois arquivos principais para configuração:

1. **`config.lua` (Compartilhado):** Permite alterar a tecla para abrir o celular (Padrão: `k`) e outras configurações visuais gerais.
2. **`server_config.lua` (Apenas Servidor):** Arquivo de segurança máxima onde você define se usará `sqlite` ou `mysql`, além de configurar os dados de conexão do banco e integração de ElementData. **Por ser server-side, nenhum jogador consegue acessar suas senhas.**

### 💾 Integração Dinâmica (ElementData e Colunas)

Você não precisa mais editar o código fonte para adaptar o mod ao seu servidor! No arquivo `server_config.lua`, dentro da sessão `integration`, você pode definir exatamente:
- Qual `element data` armazena o ID do seu jogador (Ex: `"char:id"`, `"ID"`, etc).
- O nome da tabela do seu banco de dados (Ex: `"characters"`).
- O nome de cada coluna usada pelo celular (`bank`, `name`, `lastname`).
Basta colocar os nomes que o seu servidor usa e o celular funcionará magicamente!

### 🗄️ Banco de Dados Automático (MySQL e SQLite)

O sistema de smartphone suporta tanto **MySQL** (recomendado para grandes servidores) quanto **SQLite** (perfeito para servidores locais ou testes).

**A Mágica do SQLite (Plug and Play):** 
Se você definir `type = "sqlite"` no `server_config.lua`, o mod irá criar o banco de dados e as tabelas necessárias **automaticamente** assim que for iniciado! Você não precisa rodar nenhum script SQL manualmente. É só ligar o mod e usar.

## 🚀 Funcionalidades

### ✅ Já Implementadas
- **Interface Moderna (UI/UX):** Design limpo, fluido e responsivo, construído com tecnologias web (CEF).
- **Sistema Bancário:** Aplicativo de banco completo para realizar transferências via Pix e consultar saldo em tempo real.
- **Notificações Inteligentes:** Sistema de notificações na tela (estilo *toast/swiper*) para alertas e mensagens, mesmo com o celular no bolso.
- **Física e Animações (3D):** O personagem interage com um objeto físico do celular na mão através do `pAttach`.
- **100% Standalone (Independente):** Não precisa de nenhum mod "core". Ele faz a conexão com o banco de dados sozinho.
- **Banco de Dados Híbrido Automático:** Suporte para MySQL ou SQLite. Se usar SQLite, ele cria o banco e tabelas sozinho!
- **Integração Descomplicada:** Configure o ElementData e as tabelas/colunas de banco de dados diretamente no `server_config.lua` sem mexer em código.
- **Código Totalmente Comentado em Português:** Perfeito para leigos entenderem o que cada linha de código faz.

### 🚧 Funcionalidades Futuras (Em Breve)
- **Aplicativo de Contatos:** Salvar, editar e gerenciar a agenda telefônica de outros jogadores.
- **Mensagens e Chat:** Envio de mensagens de texto estilo SMS ou WhatsApp.
- **Sistema de Ligações:** Chamadas de voz em tempo real integradas com o sistema de áudio direcional do MTA.
- **Câmera e Galeria:** Possibilidade de tirar fotos (screenshots) dentro do jogo e salvá-las na galeria.
- **Redes Sociais e Anúncios:** Aplicativos estilo Twitter ou OLX para interação global entre os jogadores.
- **Personalização:** Troca de papel de parede (Wallpapers) e temas (Dark/Light mode).

## 🤝 Como Contribuir

Este é um projeto colaborativo e toda ajuda é muito bem-vinda! Se você deseja adicionar novas funcionalidades, corrigir bugs, melhorar o código ou a interface, sinta-se à vontade para enviar as suas alterações. 

Para contribuir:
1. Faça um **Fork** deste repositório.
2. Crie uma branch para a sua modificação (`git checkout -b feature/minha-nova-funcionalidade`).
3. Faça o **Commit** das suas alterações (`git commit -m 'Adicionando minha nova funcionalidade'`).
4. Faça o **Push** para a sua branch (`git push origin feature/minha-nova-funcionalidade`).
5. Abra um **Pull Request** explicando o que foi feito.

Ficaremos muito felizes em analisar e integrar o seu código (commits) ao projeto principal!

## 📄 Licença

Este projeto é de código aberto. Sinta-se à vontade para contribuir, modificar e utilizar em seu servidor.
