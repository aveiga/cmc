---
title: Política de Privacidade — CMC
permalink: /privacy/
---

# Política de Privacidade — CMC

**Última atualização: 29 de agosto de 2026**

Aplicação **não oficial**. Sem qualquer afiliação, patrocínio ou ligação ao Colégio
Marista de Carcavelos. Todos os conteúdos pertencem ao Colégio e são lidos do seu site
público.

## Resumo

**A aplicação CMC não recolhe quaisquer dados pessoais.** Não tem contas de utilizador,
não tem publicidade, não tem ferramentas de análise (*analytics*), e nada do que faz na
aplicação é enviado para nós — porque não existe qualquer servidor nosso para onde
enviar.

## Que dados são recolhidos

Nenhuns. Concretamente:

- Não pedimos nem armazenamos nome, email, número de telefone ou qualquer outro
  identificador.
- Não usamos identificadores de publicidade (IDFA) nem rastreamento entre aplicações.
- Não integramos SDKs de terceiros de análise ou publicidade (Firebase, Crashlytics,
  Sentry, ou equivalentes).
- Não temos servidores. Não há qualquer conta, registo ou sincronização.

A única biblioteca externa usada é o [SwiftSoup](https://github.com/scinfu/SwiftSoup),
que serve exclusivamente para interpretar HTML dentro do dispositivo. Não comunica com a
rede.

## Ligações de rede

A aplicação liga-se a **um único domínio**: `marista-carcavelos.globaleduca.com`, o site
público do Colégio, para ler os destaques, o calendário e as ementas.

Como em qualquer visita a um site, o servidor do Colégio (e o serviço que o aloja) recebe
o endereço IP do dispositivo e a informação técnica normal de um pedido HTTP. Esse
tratamento é feito por essas entidades, não por nós, e rege-se pelas suas próprias
políticas. A aplicação não acrescenta qualquer identificador a esses pedidos.

Todas as ligações usam HTTPS.

## Dados guardados no dispositivo

Ficam **apenas no dispositivo** e nunca saem dele:

- **Cache dos conteúdos** (destaques, calendário, ementas), para que a aplicação
  funcione sem rede e não mostre um ecrã vazio quando o site estiver indisponível.
- **Preferência de notificações** e a referência do último destaque visto, para saber o
  que já é conhecido.

Desinstalar a aplicação apaga tudo isto. Não há cópia noutro lado.

## Notificações

As notificações são **locais**: geradas pelo próprio dispositivo quando a aplicação
deteta um destaque novo. Não usamos *push* remoto, pelo que não existe qualquer token de
dispositivo nem servidor de notificações. A permissão é pedida dentro da aplicação e pode
ser revogada a qualquer momento nas Definições do sistema.

## Calendário

Ao adicionar um evento ao calendário, a aplicação abre o **ecrã de confirmação do
sistema** — nada é escrito sem a sua confirmação explícita. A aplicação não lê o
calendário, não consulta eventos existentes e não envia informação do calendário para
lado nenhum.

## Crianças

A aplicação não recolhe dados de ninguém, incluindo menores. Não tem conteúdo gerado por
utilizadores, funcionalidades sociais nem compras.

## Alterações

Alterações a esta política serão publicadas nesta página, com a data de atualização no
topo.

## Contacto

Questões sobre privacidade: [abrir um *issue* no
GitHub](https://github.com/aveiga/cmc/issues).

---

# Privacy Policy — CMC (English)

**Last updated: 29 August 2026**

Unofficial app. Not affiliated with, sponsored by, or connected to Colégio Marista de
Carcavelos. All content belongs to the school and is read from its public website.

**CMC collects no personal data.** There are no user accounts, no advertising, no
analytics, and no servers of ours for data to be sent to.

- **No data collected** — no names, emails, phone numbers, advertising identifiers, or
  cross-app tracking. No third-party analytics or advertising SDKs.
- **One network destination** — `marista-carcavelos.globaleduca.com`, over HTTPS, to read
  the school's public pages. As with any website visit, that server and its host receive
  the device's IP address and standard HTTP request information; that processing is
  theirs, not ours. We attach no identifier to those requests.
- **On-device storage only** — a content cache (so the app works offline) and the
  notification preference. Both are deleted when the app is uninstalled.
- **Local notifications only** — generated on-device. No remote push, so no device tokens
  exist.
- **Calendar** — events are added only through the system's confirmation sheet. The app
  never reads your calendar.

Questions: [open an issue on GitHub](https://github.com/aveiga/cmc/issues).
