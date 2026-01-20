############################################
# Phase 3 — Nettoyage & structuration
# Signal : Heart Rate
############################################

# Charger les packages nécessaires
library(tidyverse)
library(data.table)
library(lubridate)

# Charger les données issues de la Phase 2

patients <- fread("data/processed/clean_patients.csv")

head(patients)



# Charger la table icu/d_items
# Objectif : identifier les itemid correspondant à la fréquence cardiaque


icu<-fread("data/raw/d_items.csv")

structure(icu)
# On remarque qu'il y a plus de 10 variables dont label
# on cherche Heart dans les label pour trouver la fréquence cardiaque
resultats <- icu[label %like% "Heart"]
print(resultats)

# on store la valeur de itemid_HR
itemid_HR <- icu$itemid[icu$label == "Heart Rate"]


# Charger la table icu/chartevents qui contient les valeurs de bpm de chaque patients
# Attention : table volumineuse

chartevents <- fread("data/raw/chartevents.csv")
str(chartevents)

dim(chartevents)

# Filtrer chartevents pour ne garder que :
# - les itemid correspondant à Heart Rate
# - les patients âgés de 65 ans et plus
# - les valeurs numériques non manquantes

itemid_HR <- 220045 # correspond au BPM

chartevents <- chartevents[
  itemid == itemid_HR &
    subject_id %in% patients$subject_id &
    !is.na(valuenum)
]
  
dim(chartevents)


# on a maintenant moins de lignes, toutes correspondant au patients de +65 ans
  

# Conserver uniquement les colonnes essentielles :
# - subject_id
# - charttime
# - heart_rate (valeur mesurée)

chartevents <- chartevents %>%
  select(-hadm_id,-stay_id,-caregiver_id, -storetime,-itemid,-value,-valueuom,-warning)


# Vérifier la qualité des données :

# Pour Valuenum
summary(chartevents$valuenum)

ggplot(chartevents, aes(x=valuenum)) +
  geom_histogram(bins = 30) +
  theme_minimal()

# On reconnait une distribution gausienne

ggplot(chartevents, aes(y = valuenum)) +
  geom_boxplot() +
  theme_minimal()

# on voit des valeurs extremes à considerer pour plus tard

# Conclusion :
# L’analyse exploratoire des mesures de fréquence cardiaque chez les patients
# âgés de + 65ans met en évidence une variabilité des valeurs observées.

# La majorité des mesures se situe dans des plages physiologiquement plausibles,
# compatibles avec des fréquences cardiaques normales ou modérément élevées
# en contexte de soins intensifs.
#
# La distribution globale de la fréquence cardiaque suggère que l’utilisation
# de seuils standards définis pour la population adulte générale pourrait
# ne pas être optimale chez les patients âgés, en particulier dans un contexte ICU.
# Cette observation justifie la poursuite du projet vers une analyse plus fine
# des distributions par groupes d’âge, et la définition de seuils adaptés
# reposant sur les données observées.


# Nettoyer les valeurs physiologiquement impossibles

chartevents <- chartevents %>%
  filter(valuenum >0) %>%
  filter(valuenum <250)

# Créer des groupes d’âge :
# - 65–75
# - 75–85
# - 85+

# Nouveau variable
patients$age_groupe <- ""


patients <- patients %>%
  mutate(age_group = case_when(
    age >= 65 & age < 75 ~ "65-74",
    age >= 75 & age < 85 ~ "75-84",
    age >= 85            ~ "85+"
  ))%>%
  select(-age_groupe)
  
head(patients)



# Joindre les informations patient aux mesures de fréquence cardiaque
# Clé de jointure : subject_id
# Type : left join (on conserve toutes les mesures HR valides)


df <- chartevents %>%
  rename(hr = valuenum) %>%
  left_join(
    patients %>%
      select(subject_id, age_group, gender, age),
    by = "subject_id"
  )
  
str(df)
head(df)

# On a maintenant un bon Data Frame contenant les informations utiles pour la suite

# Structurer les données par patient et par temps :

inherits(df$charttime, "POSIXct")
# Renvoie True si tout est au bon format


# Trie les mesures par patient et par temps
df <- df %>%
  arrange(subject_id, charttime)
head(df)

# Sauvegarder le dataset nettoyé
write.csv(df, file = "hr_clean_65plus.csv",row.names = FALSE)
