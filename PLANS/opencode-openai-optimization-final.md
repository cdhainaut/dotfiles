# Plan cible final : optimisation OpenCode / OpenAI

## Objectif

Optimiser OpenCode pour un usage hybride:
- raisonnement scientifique haut de gamme en `plan`
- build/refactor/tests avec un coût token réduit
- sous-agents spécialisés pour éviter de surconsommer les gros modèles

## Répartition cible

### `plan`
- Modèle: `openai/gpt-5.4`
- Réglages: `reasoningEffort=high`, `textVerbosity=low`, `reasoningSummary=auto`
- Usage: science, architecture, validation, arbitrages difficiles

### `build`
- Modèle: `openai/gpt-5.4-mini`
- Réglages: `reasoningEffort=low`, `textVerbosity=low`
- Usage: patchs, refactors, tests, implémentation pratique

### `small_model`
- Modèle: `openai/gpt-5.4-mini-fast`
- Usage: titres, petites tâches, assistants légers

## Sous-agents

### `cheap-explore`
- Modèle: `openai/gpt-5.4-mini-fast`
- Usage: exploration cheap, recherche, synthèse courte

### `science-review`
- Modèle: `openai/gpt-5.4`
- Usage: revue finale scientifique, unités, stabilité, hypothèses

### `codex-build` (optionnel)
- Modèle: `openai/gpt-5.1-codex-mini` ou `openai/gpt-5.2-codex`
- Usage: tâches très orientées code / repo / tests

## Règles d'économie

- Toujours demander des réponses courtes
- Limiter `steps` pour les agents secondaires
- Garder `webfetch` désactivé sur `build`
- N'utiliser le gros modèle que pour la conception et la revue

## Suivi de consommation

Utiliser:
- `opencode stats`
- `opencode stats --days 7 --models 20`
- `opencode stats --project <path> --days 30 --models 20`

## Validation finale

1. Vérifier que `plan` utilise bien `gpt-5.4`
2. Vérifier que `build` utilise bien `gpt-5.4-mini`
3. Vérifier que `cheap-explore` et `science-review` existent
4. Relancer OpenCode puis tester sur une session réelle
