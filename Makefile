# Variables
MAIN=./config_wg.sh
LIBS=$(wildcard lib/*.sh)
CONF=wg-easy.conf

.PHONY: run chmod clean reset help

run: chmod
	@echo "Lancement de Wireguard Easy Script..."
	@$(MAIN)

chmod:
	@chmod +x $(MAIN)
	@chmod +x $(LIBS)

clean:
	@echo "Suppression des fichiers temporaires et de sauvegarde..."
	@rm -f *.bak *~ lib/*.bak lib/*~

reset:
	@echo "Réinitialisation de la configuration..."
	@rm -f $(CONF)
	@rm -f lib/*.bak

help:
	@echo "Commandes disponibles :"
	@echo "  make run     : Lance le script principal"
	@echo "  make chmod   : Rend tous les scripts exécutables"
	@echo "  make clean   : Nettoie les fichiers temporaires"
	@echo "  make reset   : Supprime la configuration et les sauvegardes"