# Seuils physiologiques adaptatifs chez les patients âgés

## Présentation

Ce projet explore la pertinence des seuils physiologiques standards
utilisés en pratique clinique chez les patients âgés (≥ 65 ans),
en s’appuyant sur les données de la base clinique **MIMIC-IV**.

L’objectif principal est d’évaluer si des seuils fixes, définis pour la
population adulte générale, sont adaptés au contexte des patients âgés
hospitalisés en soins intensifs (ICU), et de proposer une approche
**data-driven, interprétable et contextualisée** basée sur les distributions
observées des signes vitaux.

Le projet se concentre principalement sur la **fréquence cardiaque (Heart Rate)**,
utilisée comme signal physiologique d’exemple.

---

## Objectifs

- Analyser la distribution de la fréquence cardiaque chez les patients ≥ 65 ans en ICU  
- Évaluer la pertinence des seuils standards (HR < 60 bpm, HR > 100 bpm)  
- Définir des **seuils adaptatifs** basés sur les percentiles de la distribution  
- Proposer un **score percentile continu**, interprétable cliniquement  
- Illustrer l’apport d’une approche IA simple et explicable pour l’aide à la décision  

---

## Données

Les données utilisées proviennent de la base **MIMIC-IV**  
(MIT Laboratory for Computational Physiology).

Tables principalement utilisées :
- `patients`
- `chartevents`
- `d_items`

Aucune donnée brute ni information permettant d’identifier un patient
n’est incluse dans ce dépôt.

Les données sont filtrées pour inclure uniquement :
- des patients âgés de **65 ans et plus**
- des mesures valides de **fréquence cardiaque**
- un contexte de **soins intensifs (ICU)**

---

## Méthodologie (vue d’ensemble)

1. Exploration démographique des patients âgés (âge, sexe)  
2. Extraction et nettoyage du signal de fréquence cardiaque  
3. Analyse exploratoire clinique des distributions globales et par groupes d’âge  
4. Comparaison avec les seuils physiologiques standards  
5. Définition de seuils adaptatifs via les percentiles  
6. Construction d’un score percentile continu  
7. Modélisation IA interprétable pour la détection de valeurs atypiques  
8. Validation qualitative et discussion clinique  

---

## Résultats clés

- Le seuil standard de bradycardie (HR < 60 bpm) correspond à une valeur rare
  dans l’ensemble des groupes d’âge étudiés.
- Le seuil standard de tachycardie (HR > 100 bpm) est fréquemment dépassé
  chez les patients âgés en ICU, ce qui limite sa capacité discriminante.
- Les seuils adaptatifs basés sur les percentiles (ex : 5e–90e) sont mieux alignés
  avec les distributions observées.
- Le **score percentile** permet de contextualiser une mesure de fréquence cardiaque
  indépendamment de l’âge, facilitant l’interprétation clinique.
- Une modélisation simple et interprétable suffit lorsque le signal est bien représenté.

---

## Limites

- Analyse limitée aux patients âgés en soins intensifs (ICU)  
- Absence de contexte clinique détaillé (diagnostics, traitements, gravité)  
- Données issues d’un seul hôpital  
- Approche descriptive et exploratoire, sans objectif prédictif clinique direct  

---


## État d’avancement

- Phase 1 : Bases en R et visualisation  
- Phase 2 : Exploration démographique des patients ≥ 65 ans  
- Phase 3 : Nettoyage et structuration du signal HR  
- Phase 4 : Analyse exploratoire clinique  
- Phase 5 : Définition de seuils adaptatifs et score percentile  
- Phase 6 : Modélisation IA interprétable  
- Phase 7 : Validation qualitative et discussion  



---

## Perspectives

Cette approche peut être étendue à d’autres signaux vitaux
(SpO₂, pression artérielle, fréquence respiratoire) ou recalibrée
dans d’autres contextes cliniques.

Elle constitue une base méthodologique pour des outils d’aide
à la décision clinique interprétables.

---
# Projet complété dans un cadre exploratoire.
