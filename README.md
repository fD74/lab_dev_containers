# Lab image a persistentní testovací kontejnery

Adresář obsahuje reprodukovatelné image pro vývoj Ansible projektů na Ubuntu
24.04 a Rocky Linux 9. Tagy `latest` vždy označují poslední lokálně sestavený
stav; image se automaticky nestahují ani nenasazují na cílové systémy.

## Image

- `ipr-ansible-lab:base-ubuntu24-latest` a
  `ipr-ansible-lab:base-rocky9-latest` vycházejí z upstream OS image. Obsahují
  jen sudo a testovací účet `tester` s neinteraktivním sudo; neobsahují
  `sc-ansible`, Ansible runtime, SOPS, age ani projektové soubory.
- `ipr-ansible-lab:ansible-dev-ubuntu24-latest` a
  `ipr-ansible-lab:ansible-dev-rocky9-latest` navíc obsahují aktuální pracovní
  kopie `ansible_mgmt` a `os_mgmt`, bootstrapový a řízený Ansible runtime,
  collections základních projektů, SOPS a age. Tematické projekty ani jejich
  manifesty se do tohoto image nepřidávají.

Ansible dev build přebírá pracovní soubory z `/home/sc-ansible/projects` včetně
necommitnutých změn. Zdrojový `projects/` je vedle `lab_dev_containers/` v workspace; build
skript z něj nejprve sestaví filtrovaný dočasný context. Proto `COPY projects/`
v Dockerfile odkazuje na adresář uvnitř tohoto contextu, nikoli na cestu vůči
Dockerfile. Z build contextu se vynechává `.git`, lokální `.ansible`,
`.envrc`, `secrets`, `artifacts` a cache; veřejný IPR CA certifikát se přidá
samostatně, pokud je dostupný. Image neobsahují age privátní klíč ani secrets.
SOPS verze se řídí bootstrapem `ansible_mgmt`; age se instaluje z repozitářů
dané distribuce.

## Sestavení

```bash
cd /home/sc-ansible
./lab_dev_containers/build-base.sh
./lab_dev_containers/build-ansible-dev.sh
```

Oba příkazy podporují výběr `ubuntu24` nebo `rocky9`, například:

```bash
./lab_dev_containers/build-base.sh rocky9
./lab_dev_containers/build-ansible-dev.sh rocky9
```

Ansible dev build automaticky sestaví odpovídající lab base, pokud jeho image
ještě neexistuje. Pro reprodukovatelný build je potřeba dostupná lokální Docker
daemon, `rsync` a síťový přístup k OS repozitářům, SOPS release a Ansible Galaxy.

## Persistentní kontejnery a projektový snapshot

Pro každý image spusť vlastní persistentní kontejner:

```bash
./lab_dev_containers/run-target.sh base ubuntu24
./lab_dev_containers/run-target.sh base rocky9
./lab_dev_containers/run-target.sh ansible-dev ubuntu24
./lab_dev_containers/run-target.sh ansible-dev rocky9
```

Každý kontejner připojí `/home/sc-ansible/projects` hostitele pouze pro čtení
do `/mnt/projects-source`. Při prvním startu base kontejner vytvoří nezávislou
kopii `ansible_mgmt`, `os_mgmt` a wrapperu `playbook` do
`/home/sc-ansible/projects`; další starty ji nepřepisují. Ansible dev
image už obsahuje snapshot zdrojů z okamžiku sestavení a read-only mount jej
také nepřepisuje. Úpravy uvnitř kontejneru proto zůstávají oddělené od host
zdroje.

Pro vývoj tematického projektu, například `esri_mgmt_portal` nebo
`esri_mgmt_monitor`, zkopíruj pouze tento projekt z read-only zdroje do
zapisovatelného snapshotu a spusť `ansible_collections.yaml`. Ten nainstaluje
collections podle manifestů přítomných projektů, včetně `community.sops`,
pokud jej vybraný projekt deklaruje. Mezilehlý adresář `out` se nepoužívá.

Shell do čistého base targetu otevři jako testovací účet a bootstrap spusť
podle dokumentace `ansible_mgmt`:

```bash
docker exec -it -u tester ipr-lab-base-ubuntu24-main bash
cd /home/sc-ansible/projects
sudo bash ansible_mgmt/tools/mk-ansible-requirements.sh
```

Ansible dev kontejner lze otevřít stejným způsobem. Po novém sestavení image
vytvoř kontejner s novým jménem instance, například
`./lab_dev_containers/run-target.sh ansible-dev ubuntu24 20261002`; existující kontejner
zachovává svůj původní image i změny ve snapshotu. Skripty existující kontejnery
automaticky nemažou ani nepřepisují.

Build context dočasných Ansible dev souborů je po buildu odstraněn. Změny v
persistentním kontejneru se zachovají při restartu, ale odstraněním kontejneru
se odstraní také jeho snapshot; před odstraněním případné změny exportuj.