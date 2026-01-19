############################################
# Phase 2 — Découverte de MIMIC-IV
############################################


# Charger les packages nécessaires (tidyverse, data.table, lubridate)
library(tidyverse)
library(data.table)
library(lubridate)


# Charger UNE table MIMIC (patients OU chartevents)
patients <- fread("~/R/adaptive-vital-sign-thresholds/data/raw/patients.csv")



# Afficher les premières lignes de la table

head(patients)


# Afficher la structure de la table (types des colonnes)

str(patients)


# Identifier les colonnes importantes (ID patient, temps, valeur)

# On pense garder Genre, anchor_age, dod 
# On regarde le nombre de personne identifier DOD

na_dod <- sum(is.na(patients$dod))
total_admitted <- dim(patients)[1]

p_na_dod <- na_dod/total_admitted

total_admitted-na_dod
# on a 38301 patients reportés mort -> bcp de données de validations
# on va rename anchor_age en age




# Filtrer les patients âgés de 65 ans et plus
patients <- patients %>%
  filter(anchor_age>=65) %>%
  mutate(age=anchor_age)%>%
  select(-anchor_age,-anchor_year,-anchor_year_group)
  


head(patients)

# Vérifier le nombre de patients et d’observations restantes

n_patients <- dim(patients)[1]
age_info <- summary(patients$age)

ggplot(patients, aes(x = age, fill = gender)) +
  geom_histogram(
    binwidth = 1,
    position = "dodge",
    color = "black",
    width = 0.9
  ) +
  theme_minimal()+
  labs(x = "Âge", y = "Effectif", title ="Répartition des patients par âge et sexe")


ggplot(patients, aes(x=gender))+
  geom_bar()+
  theme_minimal()+
  labs(x= "Genre", y = 'Effectif', title = " Nombre de patients en fonction du genre")
    
    
    
  


# Écrire en commentaire 3 observations sur la table

# 1ere observation 
# on remarque qu'après 90ans y'a un gros pic --> cela correspond à une majoration/groupement fait 
# exprès


# 2eme observation 
# On a un effectif de femmes plus eleve de peu --> bien répartis 
# Les femmes vivents plus longtemps

# 3eme observation 
# Le nombre de d'effectifs diminuent avec l'age -> Décroissance avec l’âge









