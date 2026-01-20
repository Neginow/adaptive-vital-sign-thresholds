############################################
# Phase 4 — Analyse exploratoire clinique
# Signal : Heart Rate
############################################


# Charger les données nettoyées (Phase 3)

df <- fread("data/processed/hr_clean_65plus.csv")


# Vérification rapide du dataset
# - dimensions
# - types des variables
# - valeurs manquantes éventuelles

dim(df)
# [1] 4275    6

str(df)
#Classes ‘data.table’ and 'data.frame':	4275 obs. of  6 variables:
#$ subject_id: int  
#$ charttime : POSIXct
#$ hr        : int  
#$ age_group : chr  
#$ gender    : chr  
#$ age       : int  

any(is.na(df))
#  False donc pas de valeurs manquantes


# Description statistique globale de la fréquence cardiaque
# - min, max
# - moyenne, médiane
# - quartiles
# Objectif : comprendre la "normalité" globale chez les ≥65 ans

summary(df$hr)
# Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
# 28.00   72.00   83.00   84.31   95.00  169.00 

# la médiane est de 83 bpm qu'on peut considerer normal

# Visualisation de la distribution globale de HR

ggplot(df, aes(x = hr)) +
  geom_histogram(bins = 30) +
  theme_minimal()
# On voit une distribution gaussienne, symetrique et du nombre d'occurences qui diminuent
# lorsqu'on attenint les valeurs extremes


# Analyse par groupes d’âge

df %>%
  group_by(age_group) %>%
  summarise(
    n = n(),
    mean_hr   = mean(hr, na.rm = TRUE),
    sd_hr     = sd(hr, na.rm = TRUE),
    median_hr = median(hr, na.rm = TRUE),
    q1_hr     = quantile(hr, 0.25, na.rm = TRUE),
    q3_hr     = quantile(hr, 0.75, na.rm = TRUE)
  )


ggplot(df, aes(x=hr,fill = age_group ))+
  geom_density(            # on utilise density pour avoir un lissage des histogramme pour une 
                           # meilleure visibilité des distributions
    alpha = 0.4,
    linewidth = 1
  ) +
  labs(
    x = "hr",
    y = "Densité",
    fill = "Groupe d'âge"
  ) +
  theme_minimal()

# Groupe 65–74 ans :
# La distribution de la fréquence cardiaque est centrée autour de 84–85 bpm,
# avec une dispersion modérée. La majorité des valeurs se situe entre 73 et 95 bpm,
# indiquant une régulation cardiaque encore relativement stable dans ce groupe.

# Groupe 75–84 ans :
# La fréquence cardiaque médiane est légèrement plus basse que chez les 65–74 ans,
# mais la variabilité reste comparable. La distribution est étalée,
# suggérant une hétérogénéité physiologique croissante avec l’âge.

# Groupe 85 ans et plus :
# Les valeurs centrales restent proches des groupes plus jeunes,
# mais la dispersion est légèrement plus élevée. Cela traduit une plus grande
# variabilité interindividuelle et une régulation cardiaque moins homogène
# chez les patients très âgés.

# Globalement, les distributions de fréquence cardiaque sont similaires entre les groupes d’âge,
# avec un fort chevauchement et des valeurs centrales proches. L’effet de l’âge se manifeste
# principalement par une augmentation progressive de la variabilité plutôt que par
# un changement brutal des valeurs typiques. Ces résultats suggèrent que des seuils uniques
# pourraient manquer de finesse pour interpréter la fréquence cardiaque chez les patients âgés.


# Comparaison avec les seuils standards
# - HR < 60 (bradycardie)
# - HR > 100 (tachycardie)
# Objectif : évaluer la pertinence des seuils standards chez les ≥65 ans


# Calculer la proportion globale de mesures :
# - HR < 60 bpm
# - HR > 100 bpm
# dans l’ensemble des patients ≥65 ans

df_prop <- df %>%
  mutate(prop60 = (hr<60)) %>%
  mutate(prop100 = (hr>100))

prop_60HR <- sum(df_prop$prop60)/dim(df_prop)[1]*100
prop_100HR <- sum(df_prop$prop100)/dim(df_prop)[1]*100


# Interprétation :
# Parmi les patients environ 5.7 % des mesures de fréquence
# cardiaque sont inférieures à 60 bpm, indiquant que la bradycardie est relativement rare.
# En revanche, près de 17.7 % des mesures dépassent 100 bpm, suggérant que le seuil
# standard de tachycardie correspond à une proportion non négligeable des observations.

# Pareil mais pour chaque groupe d'age
# 1er groupe  65–74
df_prop_65_74 <- df_prop %>%
  filter(age_group == "65-74")

head(df_prop_65_74)


prop_60HR_1 <- sum(df_prop_65_74$prop60)/dim(df_prop_65_74)[1]*100
prop_100HR_1 <- sum(df_prop_65_74$prop100)/dim(df_prop_65_74)[1]*100

# 2e groupe  75–84

df_prop_75_84 <- df_prop %>%
  filter(age_group == "75-84")

head(df_prop_75_84)


prop_60HR_2 <- sum(df_prop_75_84$prop60)/dim(df_prop_75_84)[1]*100
prop_100HR_2 <- sum(df_prop_75_84$prop100)/dim(df_prop_75_84)[1]*100

# 3e groupe 85+

df_prop_85 <- df_prop  %>%
  filter(age_group == "85+")

head(df_prop_85)


prop_60HR_3 <- sum(df_prop_85$prop60)/dim(df_prop_85)[1]*100
prop_100HR_3 <- sum(df_prop_85$prop100)/dim(df_prop_85)[1]*100

prop <- data.frame(
    Groupe = c("<60",">100"),
    "tout" = c(prop_60HR, prop_100HR),
    "65_74" = c(prop_60HR_1,prop_100HR_1),
    "75-84"= c(prop_60HR_2, prop_100HR_2),
    "85+" = c(prop_60HR_3,prop_100HR_3)
  
)

# HR < 60 bpm :
# La proportion globale de mesures inférieures à 60 bpm est faible (≈5.7 %),
# indiquant que la bradycardie reste un événement relativement rare chez les
# patients âgés de 65 ans et plus en ICU.

# Cette proportion est légèrement plus faible chez les 65–74 ans (≈4.9 %),
# puis augmente modestement chez les 75–84 ans (≈6.5 %) et les 85+ (≈6.5 %).
# Cela suggère que les fréquences cardiaques basses deviennent un peu plus
# fréquentes avec l’âge, tout en restant globalement peu courantes.


# HR > 100 bpm :
# Environ 17.8 % des mesures de fréquence cardiaque dépassent 100 bpm dans
# l’ensemble de la population ≥65 ans, indiquant que ce seuil est franchi
# de manière relativement fréquente en contexte ICU.

# Les proportions sont comparables entre les groupes d’âge (≈17–18 %),
# avec une légère augmentation chez les 65–74 ans (≈18.4 %).
# L’absence de diminution marquée chez les groupes plus âgés suggère que
# le seuil de tachycardie standard n’est pas plus discriminant chez les patients
# très âgés.


# Synthèse :
# Chez les patients âgés de 65 ans et plus en soins intensifs, la bradycardie
# définie par une fréquence cardiaque inférieure à 60 bpm est relativement rare.
# À l’inverse, une fréquence cardiaque supérieure à 100 bpm est observée de manière
# assez fréquente, concernant près d’une mesure sur cinq.

# Les différences entre groupes d’âge sont limitées, avec des proportions
# globalement similaires. Ces résultats suggèrent que les seuils standards
# offrent une lecture globale de la fréquence cardiaque, mais qu’ils manquent
# de finesse pour décrire les variations physiologiques observées chez les
# patients âgés en contexte ICU.

# Analyse général

# Dans les plots des dsitrbutions par groupe d'age un glissement, en effet, le centre se décale
# avec l'age de manière progressif.

# En ce qui concerne la variabilité, on constate une augmentation légère, en particulier
# chez les patients de +85ans. Cela se traduit par des distributions un peu
# plus étalées et des valeurs extrêmes légèrement plus fréquentes, suggérant une
# hétérogénéité physiologique croissante chez les patients très âgés.

# Les distributions des différents groupes d’âge se chevauchent largement.
# Cela indique que la fréquence cardiaque seule ne permet pas de discriminer
# clairement les patients selon l’âge, et que l’effet de l’âge sur la fréquence
# cardiaque reste graduel plutôt que discriminant.

# Ainsi, l’âge influence la fréquence cardiaque principalement par une
# augmentation progressive de la variabilité plutôt que par un changement marqué
# des valeurs centrales. Ces observations renforcent l’idée que des seuils uniques
# peuvent manquer de finesse pour interpréter la fréquence cardiaque chez les
# patients âgés, et soutiennent l’intérêt d’approches adaptées à l’âge.

# Limites de l’analyse :
# Cette analyse repose uniquement sur des mesures de fréquence cardiaque et ne
# tient pas compte du contexte clinique individuel des patients, notamment des
# diagnostics, traitements médicamenteux ou situations aiguës pouvant influencer
# la fréquence cardiaque. De plus, l’étude s’appuie sur des données issues de soins
# intensifs, ce qui limite la généralisation des résultats à d’autres populations.
# Enfin, l’analyse est descriptive et ne permet pas d’établir de lien causal entre
# l’âge et les variations de la fréquence cardiaque.


