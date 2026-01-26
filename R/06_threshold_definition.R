############################################
# Phase 6 — Modélisation IA interprétable
# Détection de fréquence cardiaque atypique
############################################

# Charger le dataset et les lib
library(tidyverse)
library(data.table)
library(lubridate)


df <- fread("data/processed/hr_clean_65plus_with_score.csv")


# Définir une variable cible binaire "atypique" qui vaut 1 si 
# hr_percentile <= 5 OU hr_percentile >= 95 sinon 0


df <- df %>%
  mutate(atypique=case_when(
    
    hr_percentile<= 5 | hr_percentile>= 95  ~ 1,
    TRUE   ~ 0           
    ))

pourcentage_atypique = sum(df$atypique)/dim(df)[1]
# 0.0994152
# Cette proportion est cohérente avec l’objectif du score, qui vise à identifier 
# les valeurs les plus rares au sein de chaque groupe d’âge. 
# Elle permet de cibler un nombre limité de situations potentiellement cliniquement pertinentes, 
# sans sur-déclencher d’alertes inutiles.


# Construire un modèle de type régression logistique
# Variable cible : atypique (0 / 1)

# Variables explicatives possibles :
# - hr
# - age
# - gender
# - age_group
# - hr_percentile (optionnel, à discuter)



model_1 <- glm(
  atypique ~ hr_percentile,
  data = df,
  family = binomial
)

summary(model_1)

# Le modèle logistique basé uniquement sur le percentile de la fréquence cardiaque
# ne montre pas de relation linéaire significative avec l’atypicité. Ce résultat
# est attendu, car l’atypicité est définie par les valeurs extrêmes du percentile
# (très basses ou très élevées), ce qui correspond à une relation non linéaire
# que le modèle ne peut pas capturer directement.


# La variable "distance_extreme" mesure l’éloignement d’une observation par
# rapport aux valeurs centrales de la distribution. Elle permet de transformer
# une relation en U entre percentile et atypicité en une relation monotone,
# plus adaptée à un modèle logistique simple et facilement interprétable.

# Le choix a été fait de ne pas complexifier le modèle afin de conserver une
# interprétation claire et clinique des résultats. Dans ce contexte, améliorer
# la représentation de la variable physiologique est plus pertinent que
# d’augmenter la complexité algorithmique.

df <- df %>%
  mutate(
    distance_extreme = pmin(hr_percentile, 100 - hr_percentile)
  )


summary(df$distance_extreme)


model_dist <- glm(
  atypique ~ distance_extreme,
  data = df,
  family = binomial
)


summary(model_dist)

# Le modèle logistique basé sur la distance aux extrêmes du percentile présente
# une séparation quasi parfaite entre les observations typiques et atypiques.
# La déviance résiduelle quasi nulle indique que cette variable suffit presque
# entièrement à expliquer l’atypicité définie dans ce cadre.






