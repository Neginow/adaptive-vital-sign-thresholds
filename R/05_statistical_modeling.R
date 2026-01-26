############################################
# Phase 5 — Définition de seuils adaptatifs
# Signal : Heart Rate
############################################

# Charger les packages nécessaires
library(tidyverse)
library(data.table)
library(lubridate)

# Charger les données préparées (HR, âge, groupes d’âge)
df <- fread("data/processed/hr_clean_65plus.csv")
head(df)


# Calculer les percentiles globaux de la fréquence cardiaque



quantile(df$hr,probs=c(0.05,0.1,0.9,0.95))
# On a 
#5% 10% 90% 95% 
#59  63 108 116 


# le seuil standard de HR < 60 bpm correspond à une valeur
# extrême de la distribution, tandis que le seuil de HR > 100 bpm
# se situe bien en deçà des percentiles supérieurs (90e–95e), capturant ainsi
# une proportion importante de mesures physiologiquement courantes.


# Calculer les percentiles de la fréquence cardiaque
# séparément pour chaque groupe d’âge


# 1er groupe
g1<- df %>%
  filter(age_group == "65-74") %>%
  select(-subject_id,-charttime,-age_group,-gender,-age)

quantile(g1$hr,probs=c(0.05,0.1,0.9,0.95))

# 5% 10% 90% 95% 
# 60  64 108 117 

# 2eme groupe
g2<- df %>%
  filter(age_group == "75-84") %>%
  select(-subject_id,-charttime,-age_group,-gender,-age)

quantile(g2$hr,probs=c(0.05,0.1,0.9,0.95))

# 5% 10% 90% 95% 
# 58  62 108 115 

# 3eme groupe
g3<- df %>%
  filter(age_group == "85+") %>%
  select(-subject_id,-charttime,-age_group,-gender,-age)

quantile(g3$hr,probs=c(0.05,0.1,0.9,0.95))

#5%   10%   90%   95% 
#58.0  61.0 106.6 115.3 



# Interprétation :
# Les percentiles de fréquence cardiaque sont globalement stables entre les
# groupes d’âge, avec des seuils bas (5e–10e percentiles) compris entre 58 et
# 64 bpm. Le seuil standard de bradycardie (HR < 60 bpm) correspond ainsi à une
# valeur rare et cohérente dans l’ensemble des groupes étudiés.
#
# En revanche, les seuils hauts (90e–95e percentiles) se situent entre 106 et
# 117 bpm selon l’âge, indiquant que le seuil standard de tachycardie (HR > 100 bpm)
# est inférieur aux valeurs réellement extrêmes observées chez les patients âgés
# en soins intensifs.
#
# L’effet de l’âge se traduit principalement par une augmentation progressive de
# la variabilité, sans déplacement marqué des valeurs centrales, suggérant qu’une
# adaptation graduelle des seuils basée sur les distributions observées est plus
# pertinente que l’utilisation de seuils fixes.


# Proposer des seuils adaptatifs par groupe d’âge
thresholds <- df %>%
  group_by(age_group) %>%
  summarise(
    low_threshold  = quantile(hr, 0.05),
    high_threshold = quantile(hr, 0.90)
  )

thresholds


# Visualiser les seuils adaptatifs sur les distributions
ggplot(df, aes(x = hr, fill = age_group)) +
  geom_density(alpha = 0.4) +
  geom_vline(
    data = thresholds,
    aes(xintercept = low_threshold, color = age_group),
    linetype = "dashed",
    linewidth = 1
  ) +
  geom_vline(
    data = thresholds,
    aes(xintercept = high_threshold, color = age_group),
    linetype = "dashed",
    linewidth = 1
  ) +
  geom_vline(xintercept = 60, linetype = "solid", color = "black") +
  geom_vline(xintercept = 100, linetype = "solid", color = "black") +
  theme_minimal() +
  labs(
    x = "Fréquence cardiaque (bpm)",
    y = "Densité",
    fill = "Groupe d'âge",
    title = "Seuils adaptatifs de fréquence cardiaque par groupe d'âge"
  )


# Discuter la pertinence clinique des seuils proposés
# - cohérence physiologique
# - comparaison avec seuils standards
# - avantages / limites



# Les seuils adaptatifs proposés reposent sur les percentiles observés
# de la distribution de la fréquence cardiaque chez les patients âgés.
# Le seuil bas (5e percentile) est proche du seuil standard de bradycardie
# (HR < 60 bpm), confirmant la cohérence physiologique de ce dernier.
#
# En revanche, les seuils hauts basés sur le 90e percentile se situent
# nettement au-dessus du seuil standard de tachycardie (HR > 100 bpm),
# suggérant que ce seuil capte de nombreuses valeurs physiologiquement
# fréquentes chez les patients âgés en soins intensifs.
#
# L’approche adaptative permet de mieux contextualiser une mesure de
# fréquence cardiaque en fonction de l’âge, tout en restant interprétable.
# Elle offre une alternative aux seuils fixes, en réduisant les alertes
# potentiellement non pertinentes, sans exclure les valeurs réellement
# atypiques.
#
# Toutefois, ces seuils restent descriptifs et ne tiennent pas compte
# du contexte clinique individuel. Ils doivent être envisagés comme
# un outil d’aide à la décision, et non comme un critère diagnostique.


# Score Continu

# Créer une fonction qui calcule le percentile d’une valeur
# par rapport à un vecteur de référence

# La fonction doit prendre :
# - une valeur hr individuelle
# - un vecteur de HR du groupe d’âge correspondant

percentile_hr <- function(hr,v_hr){
  F<- ecdf(v_hr)
  return (F(hr)*100)
  
  
}



# Appliquer le score percentile à chaque observation

df<- df %>%
  group_by(age_group) %>%
  mutate(hr_percentile=percentile_hr(hr,hr))

# Vérifier le score obtenu


summary(df$hr_percentile)
# Min.   1st Qu.    Median      Mean   3rd Qu.      Max. 
#0.04808  25.33654  51.36691  50.87065  75.62500 100.00000 
# on a bien entre 0 et 100

head(df[, c("age_group", "hr", "hr_percentile")])
#  age_group    hr hr_percentile
#<chr>     <int>         <dbl>
#  1 75-84        92          71.5
#. 2 65-74        86          56.7
#. 3 65-74        84          52.0
#. 4 75-84        70          25.2
#. 5 75-84        70          25.2
#. 6 65-74        76          32.0


# Visualiser la distribution du score percentile


ggplot(df, aes(x = hr_percentile)) +
  geom_histogram(bins = 40, fill = "blue", color = "white") +
  facet_wrap(~ age_group) +
  labs(
    title = "Distribution du percentile HR par groupe d'âge",
    x = "Percentile HR",
    y = "Nombre d'observations"
  ) +
  theme_minimal()

# Interprétation :
# La distribution du score percentile de la fréquence cardiaque est globalement
# homogène au sein de chaque groupe d’âge, couvrant l’ensemble de l’intervalle
# 0–100. Cela indique que le score est correctement calibré et qu’il reflète
# la position relative de chaque mesure au sein de la distribution de son
# groupe d’âge.
#
# Cette répartition quasi uniforme est attendue pour un score percentile :
# une valeur proche de 50 correspond à une fréquence cardiaque typique du groupe,
# tandis que des valeurs élevées (ex : ≥ 90e percentile) représentent des
# fréquences cardiaques rares et potentiellement cliniquement pertinentes
# dans ce contexte d’âge.
#
# La comparaison entre groupes d’âge montre des distributions similaires,
# confirmant que le score percentile permet une normalisation efficace
# des valeurs de fréquence cardiaque indépendamment de l’âge.
# Ainsi, une même valeur de percentile possède une signification comparable
# chez un patient de 65–74 ans comme chez un patient de 85 ans et plus,
# ce qui n’est pas le cas avec des seuils absolus en bpm.






# Sauvegarder le dataset enrichi avec le score percentile


write.csv(df, file = "hr_clean_65plus_with_score.csv",row.names = FALSE)

