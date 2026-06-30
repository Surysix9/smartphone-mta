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

### Tela Inicial
![Home](prints/home.png)

### Sistema Bancário
![Bank](prints/bank.png)
![Bank 2](prints/bank2.png)

### Notificações
![Notificações](prints/swipernotifications.png)

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

### 💾 ElementData (Integração de Dados)

O sistema foi construído de forma que algumas funcionalidades consumam ou modifiquem os dados do jogador utilizando `elementdata`. 

Para que o celular reflita as informações reais do jogador (como saldo bancário, dinheiro em mãos, número do telefone, etc.), é necessário que o seu gamemode/framework esteja setando esses dados no elemento do jogador. 

Verifique no código fonte quais as strings exatas de `elementdata` o script está buscando e faça a adaptação necessária para o padrão do seu servidor (por exemplo, se o seu servidor usa `setElementData(player, "bank_money", valor)`, certifique-se de que o phone busca por `"bank_money"` ou altere no phone para o nome da data do seu servidor).

### 🗄️ Banco de Dados (MySQL e SQLite)

O sistema de smartphone utiliza **MySQL** como padrão para o salvamento de contatos, mensagens e outras informações. O MySQL é recomendado para garantir a melhor performance em servidores. 

No entanto, caso você não possua um banco de dados MySQL configurado ou prefira uma solução mais simples, o script **pode ser facilmente configurado para utilizar SQLite**. Basta alterar a configuração de conexão no arquivo server-side correspondente para alternar o modo de salvamento.

## 📄 Licença

Este projeto é de código aberto. Sinta-se à vontade para contribuir, modificar e utilizar em seu servidor.
