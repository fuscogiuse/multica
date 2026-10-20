# Calm Tasks sul tuo Mac

Calm Tasks gira sul tuo Mac. Lo apri dal Dock del Mac e dall'iPhone, anche fuori casa, tramite Tailscale. Tailscale crea una rete privata tra i tuoi dispositivi: nessuno su internet vede l'app.

Basato su [Multica](https://github.com/multica-ai/multica).

## Una volta sola

1. Installa [Docker Desktop](https://www.docker.com/products/docker-desktop/) e aprilo.
2. Installa [Tailscale](https://tailscale.com/download/mac) e accedi.
3. Nel pannello di Tailscale (admin › DNS) attiva **MagicDNS** e **HTTPS Certificates**.
4. Nel Terminale:

```bash
git clone -b calm-ui https://github.com/fuscogiuse/multica
cd multica
bash scripts/calm-mac.sh setup
```

La prima volta ci vogliono 10–15 minuti. Alla fine lo script stampa il tuo indirizzo privato, del tipo `https://nome-mac.tuarete.ts.net`.

## Accedere

Apri l'indirizzo e inserisci la tua email. Il codice di accesso non arriva per email: lo leggi così.

```bash
bash scripts/calm-mac.sh code
```

## Installare l'app

- **Mac:** apri l'indirizzo in Safari, poi File › Aggiungi al Dock.
- **iPhone:** installa Tailscale e accedi con lo stesso account. Apri l'indirizzo in Safari, poi Condividi › Aggiungi alla schermata Home.

## Agenti Claude

Lo script installa la CLI `multica` e avvia il programma che fa girare gli agenti sul Mac. Gli agenti funzionano solo quando il Mac è acceso.

## Comandi

| Comando | Cosa fa |
|---|---|
| `bash scripts/calm-mac.sh code` | Mostra l'ultimo codice di accesso |
| `bash scripts/calm-mac.sh update` | Scarica gli aggiornamenti e ricostruisce l'app |
| `bash scripts/calm-mac.sh stop` | Spegne tutto |
