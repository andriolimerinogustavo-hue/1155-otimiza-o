# Como contribuir

1. Faça um fork e crie uma branch (`git checkout -b minha-melhoria`).
2. Mantenha o projeto **sem dependências externas** (apenas biblioteca padrão).
3. Todo tweak que muda o registro deve usar `definir_reg(...)`, para que o backup e o "Reverter" funcionem.
4. Tweaks que não usam o registro (como `powercfg`) precisam guardar o estado original em `backup.json` e tratá-lo em `reverter()`.
5. Teste em uma máquina virtual ou com ponto de restauração criado.
6. Abra um pull request explicando **o que o tweak faz** e **como desfazer**.

Não serão aceitos tweaks que ocultem o que fazem, enviem dados pela rede ou desativem proteções sem confirmação explícita do usuário.
