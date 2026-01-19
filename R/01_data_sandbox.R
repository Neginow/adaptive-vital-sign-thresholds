############################################
# 01_data_sandbox.R
# Objectif : Apprendre R pour la data
# Dataset : mtcars (intégré à R)
############################################


# Charger le package tidyverse
library(tidyverse)

# Charger le dataset mtcars dans un objet nommé cars
cars <- mtcars

# Afficher les 6 premières lignes du dataset
print(cars[1:6,])


# Afficher la structure du dataset
str(cars)


# Filtrer les voitures avec une consommation mpg > 20
# Stocker le résultat dans cars_filtered

cars_filtered<-cars[cars$mpg>20,]
print(cars_filtered)



# Créer une nouvelle variable "power_to_weight"
# Ajouter cette variable à cars_filtered


cars_filtered$power_to_weight <- cars_filtered$hp / cars_filtered$wt


# Vérifier que la nouvelle variable existe


head(cars_filtered)


# Créer un graphique avec ggplot2 :
# - axe x : hp
# - axe y : mpg
# - points
# - utiliser cars_filtered comme dataset


ggplot(cars_filtered, aes(hp,mpg))+
  geom_point()



# Amélioration du graphique :
# - ajouter un titre
# - ajouter des labels pour les axes
# - thème minimal

ggplot(cars_filtered, aes(hp,mpg))+
  geom_point()+
  labs(x="hp",y="mg",title="graphique")+
  theme("bottom")


# Colorer les points en fonction du nombre de cylindres (cyl)

ggplot(cars_filtered, aes(hp,mpg, colour = cars_filtered$cyl))+
  geom_point()+
  labs(x="hp",y="mg",title="graphique")+
  theme_minimal()


## CORRECTION
cars1 <- mtcars %>%
  filter(mpg>20) %>%
  mutate(p_w=hp/wt)

print(cars1)