<div align="center">

[English](ADVENTURE_SPEC.md) · [한국어](ADVENTURE_SPEC.ko.md) · [日本語](ADVENTURE_SPEC.ja.md) · **Deutsch**

</div>

# Implementierungsspezifikation des Pawprint-Abenteuermodus

Dieses Dokument beschreibt die **aktuelle rundenbasierte Abenteuer-Implementierung** im
Entwicklungszweig für die RPG-Integration, der die ursprüngliche Oberfläche von Pawprint 0.10.0
beibehält. Diese Entwicklungsversion ist nicht im öffentlichen Pawprint-0.10.0-DMG enthalten.
Maßgeblich sind hier weder Ideen noch spätere Ziele, sondern die Zahlen und Regeln des derzeit
ausgeführten Codes.

> Kurz gesagt: Der Seltenheitsrang einer Katze wirkt sich in kleinem Maß auf HP, Angriff und
> Verteidigung aus. **Das Abenteuerlevel schaltet auf Level 2, 4 und 6 Routen frei, erhöht aber
> weiterhin keine Kampfwerte.** Bindung und Routenstempel bleiben gespeicherte Zähler ohne
> Kampfwirkung.

## Auf einen Blick

| Punkt | Aktuelle Implementierung |
|---|---|
| Gruppe | Genau 3 verschiedene Katzen aus vergangenen Tagen |
| Expeditionsablauf | Gefecht → Relikt → Gefecht → Relikt → Bosskampf |
| Aktion | Pro Runde 1 Katze wählen und ihren Standardangriff oder ihre Rollenfähigkeit einsetzen |
| Routen | 6 einzeln ausgestaltete Routen für alle Affinitäten; 3 davon werden durch Level freigeschaltet |
| Kampfressourcen | Gemeinsame Gruppen-HP und gemeinsames Mana |
| Dauerhafter Fortschritt | Abenteuer-XP (das Level wird daraus berechnet), Abschlüsse, Routenstempel und Bindung je Katze |
| Vorübergehende Belohnung | Bis zu 2 Relikte, die nur für die laufende Expedition gelten |
| Automatischer Fortschritt | Keiner. Nur ein ausdrücklicher Tastendruck führt einen Zug aus |
| Wertebonus durch Level | Keiner |
| Freischaltung durch Level | Garten im Morgengrauen auf Level 2, Mittagsbahnhof auf Level 4, Labor der tiefen Nacht auf Level 6 |
| Wirkung von Bindung und Stempeln | Nur die Zähler werden gespeichert; Kampfeffekte und Verwendung gibt es nicht |
| Wiederherstellung einer laufenden Expedition | Keine. Nach einem Neustart der App wird sie nicht fortgesetzt |

Der normale Ablauf sieht so aus:

```text
Abenteuer aus der Katzengalerie öffnen
  → 3 Katzen aus vergangenen Tagen wählen
  → Route wählen
  → Gefecht 1
  → 1 Relikt wählen
  → Gefecht 2
  → 1 Relikt wählen
  → Bosskampf
  → Punkte, Rang und Belohnungen abrechnen
```

## Drei voneinander getrennte Einstufungen

| Bezeichnung | Bereich | Grundlage | Aktuelle Wirkung |
|---|---|---|---|
| Seltenheitsrang der Katze | S~D | Bestehende Pawpet-Seltenheit | Kleiner Bonus auf HP, Angriff und Verteidigung |
| Ergebnisrang der Expedition | S~D | Abschlusspunktzahl oder Fehlschlag | Bestimmt die Basis-XP vor dem Routenmultiplikator |
| Abenteuerlevel | Ab 1, ohne Obergrenze | Gesammelte Abenteuer-XP | Schaltet auf Level 2, 4 und 6 Routen frei; keine Werteskalierung |

Der S-Rang einer Katze und ein S-Rang als Expeditionsergebnis teilen sich nur den Namen. Weder
Ergebnisrang noch XP, Abenteuerlevel, Bindung oder Routenstempel überschreiben den Seltenheitsrang
einer Katze oder ändern ihre Kampfwerte. Das Abenteuerlevel verändert nur die Routenverfügbarkeit.

## Katzen für das Abenteuer

### Kandidaten und Gruppenregeln

- Kandidaten sind nur abgeschlossene Galeriekatzen von Tagen vor dem heutigen Tag. Die heutige
  Katze ist ausgeschlossen.
- Die grundlegende Kandidatenliste und die automatische Empfehlung werden vom neuesten Datum aus
  verarbeitet. Im HUD erscheinen die Katzen nach Rang S→A→B→C→D; innerhalb desselben Rangs steht
  das neueste Datum zuerst.
- Eine Gruppe braucht genau 3 Katzen mit unterschiedlichen Datums-IDs.
- Rollen dürfen sich wiederholen. Wächter, Angreifer und Unterstützer müssen nicht zwingend je
  einmal vertreten sein.
- Die automatische Empfehlung wählt nach Möglichkeit zuerst je 1 Katze pro Rolle und füllt
  freie Plätze anschließend mit den neuesten Kandidaten.
- Eine Gruppe mit allen drei Rollen erhält keinen eigenen Zahlenbonus. Sie hat jedoch den
  taktischen Vorteil, auf jede Gegnerabsicht reagieren zu können.

### Pawpet-Aussehen in RPG-Eigenschaften übersetzen

Nur vier Eigenschaften der bestehenden Katze werden direkt an die Abenteuer-Engine übergeben.
Andere Merkmale des Aussehens und der Aktivität werden nicht direkt übermittelt; fließen sie jedoch
in Pawpets vorhandene Seltenheitsberechnung ein, können sie über den Katzenrang indirekt HP,
Angriff und Verteidigung beeinflussen.

| Pawpet-Eigenschaft | RPG-Eigenschaft |
|---|---|
| Muster (`pattern`) | Rolle |
| Aura (`aura`) | Affinität |
| Ausdruck (`expression`) | Passivfähigkeit |
| Seltenheitsrang (`rarityGrade`) | Katzenrang |

#### Muster → Rolle

| Mustercode | Rolle |
|---|---|
| `plain`, `tuxedo`, `bicolor` | Guardian (Wächter, `guardian`) |
| `tabby`, `spotted`, `calico` | Striker (Angreifer, `striker`) |
| `colorpoint`, `star` | Support (Unterstützer, `support`) |

#### Ausdruck → Passivfähigkeit

| Ausdruckscode | Passivfähigkeit |
|---|---|
| `content`, `zen` | Steady (Gelassenheit, `steady`) |
| `sleepy`, `tired`, `dizzy` | Resilient (Widerstandskraft, `resilient`) |
| `determined`, `focused`, `sparkle` | Focused (Fokus, `focused`) |
| `chaotic`, `mischief` | Opportunist (Gelegenheitsbonus, `opportunist`) |
| `surprised`, `wide` | Alert (Wachsamkeit, `alert`) |

#### Aktivitätszeit → Aura → Affinität

Die Aura folgt den bestehenden Pawpet-Regeln und wird im Verhältnis 1:1 an die
Abenteuer-Affinität mit demselben Zeitfenstercode übergeben. Als maßgebliche Uhrzeit gilt in dieser Reihenfolge
`Goldene Stunde → Stunde der geschäftigsten Minute → erste Aktivität → Mittag`.

| Maßgebliche Uhrzeit | Pawpet-Aura | Abenteuer-Affinität |
|---:|---|---|
| 00:00~04:59 | Frühe Stunden (`deepNight`) | Tiefe Nacht (`deepNight`) |
| 05:00~07:59 | Morgengrauen (`dawn`) | Morgengrauen (`dawn`) |
| 08:00~11:59 | Morgen (`morning`) | Morgen (`morning`) |
| 12:00~16:59 | Nachmittag (`afternoon`) | Nachmittag (`afternoon`) |
| 17:00~20:59 | Abend (`evening`) | Abend (`evening`) |
| 21:00~23:59 | Nacht (`night`) | Nacht (`night`) |

### Seltenheit und Katzenrang

Der im Abenteuer verwendete Rang wird nicht direkt vom Rang der täglichen Aktivitätspunktzahl
übernommen. Er ist Pawpets bereits vorhandener **Seltenheitsrang**.

```text
Seltenheitsrohwert =
  0.70 × Seltenheitspunkte der Gegenstände
  + 0.30 × (Pawpet-Aktivitätsaufwand × 100)

Ganzzahlige Seltenheit = Seltenheitsrohwert auf die nächste ganze Zahl runden
```

Der Pawpet-Aktivitätsaufwand liegt im Bereich `0...1`, die Seltenheitspunkte der Gegenstände und
der Rohwert jeweils im Bereich `0...100`. Der Rohwert wird bei der Berechnung auf zwei
Nachkommastellen gerundet; der Abenteuer-Rang richtet sich anschließend nach der erneut auf die
nächste ganze Zahl gerundeten Seltenheit. Dieser Wert wird aus den vorhandenen Tagesdaten neu
berechnet und ist kein eigenes gespeichertes RPG-Feld.

| Ganzzahlige Seltenheit | Katzenrang |
|---:|---:|
| 85 oder höher | S |
| 70~84 | A |
| 50~69 | B |
| 30~49 | C |
| 0~29 | D |

Die Abenteuer-Engine erhält nur diesen endgültigen Rang und berechnet weder Seltenheit noch
Aufwand erneut.

## Gruppenwerte

### Schreibweise der Berechnungen

| Zeichen | Bedeutung |
|---|---|
| `A` | Angriffskraft der handelnden Katze einschließlich Rangbonus |
| `G` | Verteidigungskraft der handelnden Katze einschließlich Rang- und Gelassenheitsbonus |
| `P` | Aktuelle Kampfkraft des Gegners |
| `HPmax` | Summe der maximalen HP aller drei Katzen |
| `w` | Deterministische Zufallsschwankung dieses Zuges |

Divisionen positiver Zahlen sind Ganzzahldivisionen; der Nachkommateil wird verworfen.

### Grundwerte nach Rolle

| Rolle | Basis-HP | Basisangriff | Basisverteidigung | Basisheilung | Rollenfähigkeit |
|---|---:|---:|---:|---:|---|
| Guardian (Wächter) | 112 | 22 | 10 | 0 | Paw Shield (Pfotenschild) |
| Striker (Angreifer) | 100 | 30 | 2 | 0 | Lightning Pounce (Blitzsprung) |
| Support (Unterstützer) | 106 | 20 | 4 | 10 | Comforting Groom (Wohltuende Fellpflege) |

Die genauen Schadens-, Verteidigungs- und Heilungsboni der Rollenfähigkeiten stehen in den
Kampfformeln weiter unten.

### Bonus durch den Katzenrang

| Katzenrang | Interner Bonus `B` | HP-Zuwachs | Angriffszuwachs | Verteidigungszuwachs | Heilungszuwachs |
|---|---:|---:|---:|---:|---:|
| D | 0 | 0 | 0 | 0 | 0 |
| C | 2 | 2 | 1 | 0 | 0 |
| B | 4 | 4 | 2 | 1 | 0 |
| A | 6 | 6 | 3 | 1 | 0 |
| S | 8 | 8 | 4 | 2 | 0 |

```text
Maximale HP = Basis-HP der Rolle + B
Angriffskraft = Basisangriff der Rolle + B / 2
Verteidigungskraft = Basisverteidigung der Rolle + B / 4 + (3 bei Gelassenheit)
Heilungskraft = (10 für Unterstützer, sonst 0) + (3 bei Fokus)
```

Ohne Passivfähigkeiten ergeben sich je Rolle und Rang die folgenden tatsächlichen Werte. Jede
Zelle steht in der Reihenfolge `HP / Angriff / Verteidigung`.

| Rang | Wächter | Angreifer | Unterstützer |
|---|---:|---:|---:|
| D | 112 / 22 / 10 | 100 / 30 / 2 | 106 / 20 / 4 |
| C | 114 / 23 / 10 | 102 / 31 / 2 | 108 / 21 / 4 |
| B | 116 / 24 / 11 | 104 / 32 / 3 | 110 / 22 / 5 |
| A | 118 / 25 / 11 | 106 / 33 / 3 | 112 / 23 / 5 |
| S | 120 / 26 / 12 | 108 / 34 / 4 | 114 / 24 / 6 |

Der Seltenheitsrang erhöht die Heilungskraft nicht. Da gleiche Rollen mehrfach vorkommen dürfen,
liegt der mögliche Bereich der maximalen Gruppen-HP bei `300...360`.

### Gemeinsame Gruppen-HP und handelnde Katze

- Die maximalen HP der drei Katzen werden zu einem gemeinsamen HP-Vorrat der Gruppe addiert.
- Es gibt weder individuelle HP noch einen individuellen Kampfunfähigkeitszustand.
- Pro Runde gehen nur Angriff, Verteidigung, Affinität und Passivfähigkeit der gewählten handelnden
  Katze in die Aktionsberechnung ein.
- Die beiden nicht handelnden Katzen tragen in dieser Runde nur zu den gemeinsamen maximalen HP
  bei.
- Die angezeigte Verteidigung `G` wird nicht unverändert vom Schaden abgezogen. Für die
  grundlegende Schadensminderung wird `G / 2` verwendet.

Der rangbedingte Verteidigungsbonus wird zunächst auf `G` angewendet und durchläuft danach erneut
die Ganzzahldivision `G / 2`. Verteidigung `+1` führt deshalb nicht bei jeder Katze und in jeder
Runde sofort zu Schadensminderung `+1`.

## Runden und Aktionen

### Standardangriff

```text
Anfangsschaden = max(1, 2A / 3 + w), w = -2...2
```

- Stellt 1 Punkt gemeinsames Mana wieder her, höchstens bis zum Maximum.
- Erhält keinen rollenspezifischen Schadensbonus einer Rollenfähigkeit.
- Auch ein Unterstützer heilt mit einem Standardangriff nicht.
- Passt die Rolle zur angekündigten Gegnerabsicht, kann der Angriff den schwächeren Konterbonus
  erhalten und als erfolgreicher Konter gelten.

### Rollenfähigkeit

```text
Anfangsschaden = A + w + rollenspezifischer Schadensbonus, w = -2...2
```

| Rolle | Rollenspezifischer Schadensbonus | Zusatzeffekt |
|---|---:|---|
| Wächter | +4 | Schadensminderungspotenzial `+8` |
| Angreifer | +8 | Kein Zusatzeffekt |
| Unterstützer | +0 | Heilt die Gruppe |

Eine Rollenfähigkeit verbraucht 1 Punkt gemeinsames Mana. Bei 0 Mana wird die Aktion selbst
abgelehnt; weder Runde noch Zufallszustand ändern sich.

### Reihenfolge der Spielerschadensberechnung

1. Anfangsschaden des Standardangriffs oder der Rollenfähigkeit berechnen.
2. Boni durch Affinitätsübereinstimmung, Passivfähigkeit, Konter der Gegnerabsicht und Relikte
   addieren.
3. Befindet sich der Gegner in Abwehrhaltung und wurde nicht mit der Angreiferrolle gekontert,
   seine Verteidigung `max(6, P / 5)` abziehen.
4. Den tatsächlichen Schaden auf
   `min(aktuelle Gegner-HP, max(1, versuchter Schaden - Gegnerverteidigung))` begrenzen.

Eine gültige Aktion fügt dem Gegner mindestens 1 Schaden zu. Der tatsächlich protokollierte Wert
kann seine verbleibenden HP nicht überschreiten. Ein Effekt mit `Schaden +4` kann unmittelbar vor
dem besiegenden Treffer daher kleiner als 4 erscheinen.

## Affinität und Passivfähigkeiten

### Affinitätsübereinstimmung

Nur wenn die Affinität der handelnden Katze **genau** mit der des Gegners übereinstimmt, erhält sie
einen Schadensbonus.

| Aktion | Schadensbonus bei Übereinstimmung |
|---|---:|
| Standardangriff | `max(2, A / 10)` |
| Rollenfähigkeit | `max(3, A / 6)` |

Zwischen den Affinitäten gibt es weder ein Schere-Stein-Papier-System noch nachteilige
Wechselwirkungen. Übereinstimmung gibt einen Bonus, alles andere ist neutral. Auch die Affinitäten
der beiden nicht handelnden Katzen wirken sich in dieser Runde nicht aus.

### Wirkungen der Passivfähigkeiten

| Passivfähigkeit | Bedingung | Aktuelle rundenbasierte Wirkung |
|---|---|---|
| Gelassenheit | Immer | Verteidigung `+3`, zusätzlich Schadensminderung `+4` beim Gegenangriff |
| Widerstandskraft | Gruppen-HP zu Beginn der Aktion bei höchstens 50% der maximalen HP | Zusätzliche Schadensminderung `+8` |
| Fokus | Rollenfähigkeit wird eingesetzt | Heilungskraft `+3` und Heilung der Rollenfähigkeit `+4` |
| Opportunist | 25% Chance bei jeder Aktion | Schaden `+7` |
| Wachsamkeit | Erste Runde jedes Kampfes | Schaden `+5` |

Der Verteidigungsbonus `+3` von Gelassenheit fließt in `G / 2` ein; danach kommen die weiteren
`+4` Schadensminderung getrennt hinzu. Die 50%-Bedingung der Widerstandskraft wird vor der Heilung
dieses Zuges geprüft. Wachsamkeit kann nicht nur in der ersten Runde der ganzen Expedition,
sondern jeweils in der ersten Runde aller drei Kämpfe ausgelöst werden.

## Gegnerabsichten und Konter

Die Gegnerabsicht ist offen sichtbar. Wird eine Katze mit der passenden Rolle gewählt, gilt auch
ein Standardangriff als erfolgreicher Konter; die Rollenfähigkeit wirkt jedoch stärker.

| Gegnerabsicht | Konterrolle | Wirkung ohne Konter | Konter mit Rollenfähigkeit | Konter mit Standardangriff |
|---|---|---|---|---|
| Heavy Strike (Schwerer Hieb) | Guardian (Wächter) | Hoher Gegnerangriff | Schaden `+3`, Schadensminderung `+max(12, P / 3)` | Schaden `+1`, Hälfte des vorherigen Minderungsbonus |
| Guarded Stance (Abwehrhaltung) | Striker (Angreifer) | Gegnerverteidigung `max(6, P / 5)` | Entfernt Gegnerverteidigung, Schaden `+10` | Entfernt Gegnerverteidigung, Schaden `+5` |
| Draining Mist (Zehrender Nebel) | Support (Unterstützer) | Zusatzschaden `max(8, P / 7)` | Entfernt Zusatzschaden, Schaden `+3`, Schadensminderung `+max(8, P / 5)`, Heilung `+8` | Entfernt Zusatzschaden, Schaden `+1`, Hälfte des vorherigen Minderungsbonus, keine Heilung |

Auch die unabhängige Zufallsschwankung `w` des Gegnerangriffs liegt bei `-2...2`.

| Gegnerabsicht | Versuchter Gegnerangriff |
|---|---:|
| Heavy Strike (Schwerer Hieb) | `3P / 4 + w` |
| Guarded Stance (Abwehrhaltung) | `2P / 5 + w` |
| Draining Mist (Zehrender Nebel) ohne Konter | `P / 2 + max(8, P / 7) + w` |
| Draining Mist (Zehrender Nebel) mit Konter | `P / 2 + w` |

Der Gegnerangriff wird vor der Schadensminderung auf mindestens 1 begrenzt.

## Verteidigung und erlittener Schaden

```text
Schadensminderungspotenzial =
  G / 2
  + Aktionsbonus des Wächters
  + Konterbonus der Gegnerabsicht
  + Bonus der Passivfähigkeit
  + Reliktbonus
```

| Bestandteil | Bonus auf die Schadensminderung |
|---|---:|
| Standardangriff des Wächters | +3 |
| Rollenfähigkeit des Wächters | +8 |
| Gelassenheit | +4, getrennt vom Effekt Verteidigung `G +3` |
| Widerstandskraft bei höchstens 50% HP | +8 |
| Gepolsterter Umhang | +4 |
| Konter gegen Schweren Hieb oder Zehrenden Nebel | Wert aus der Kontertabelle oben |

```text
Tatsächliche Schadensminderung = min(Gegnerangriff, max(0, Schadensminderungspotenzial))
Erlittener Schaden = min(Gruppen-HP nach Heilung, max(0, Gegnerangriff - tatsächliche Schadensminderung))
```

Wird der Gegner durch die Spieleraktion zuerst besiegt, führt er keinen Gegenangriff aus. Sowohl
der erlittene Schaden als auch die protokollierte Schadensminderung sind dann 0.

## Heilung

Heilung entsteht nur durch Rollenfähigkeiten. Sie wird nach dem Spielerschaden, aber vor dem
Gegenangriff des Gegners angewendet.

```text
Mögliche Heilung =
  Heilungskraft
  + Bonus der Unterstützer-Rollenfähigkeit
  + Konterbonus gegen Zehrenden Nebel
  + Fokusbonus der Rollenfähigkeit
  + Bonus des Heilkrauts

Tatsächliche Heilung = min(mögliche Heilung, HPmax - aktuelle Gruppen-HP)
```

| Bestandteil | Heilungsbonus |
|---|---:|
| Unterstützer-Rollenfähigkeit | +12 |
| Konter gegen Zehrenden Nebel mit einem Unterstützer | +8 |
| Rollenfähigkeit mit Fokus | +4 |
| Unterstützer-Rollenfähigkeit mit Heilkraut | +8 |

Typische mögliche Heilungsmengen sind:

| Handelnde Katze | Normale Rollenfähigkeit | Konter gegen Zehrenden Nebel | Mit Heilkraut: normal / Konter |
|---|---:|---:|---:|
| Wächter/Angreifer ohne Fokus | 0 | Nicht zutreffend | Nicht zutreffend |
| Wächter/Angreifer mit Fokus | 7 | Nicht zutreffend | Nicht zutreffend |
| Unterstützer ohne Fokus | 22 | 30 | 30 / 38 |
| Unterstützer mit Fokus | 29 | 37 | 37 / 45 |

Die Passivfähigkeit Fokus erzeugt auch bei den Rollenfähigkeiten von Wächtern und Angreifern eine
mögliche Heilung von 7. Wurden tatsächlich keine HP verloren, beträgt die Heilung dennoch 0. Die
Passivfähigkeit `Widerstandskraft (resilient)` erhöht bei niedrigen HP die Verteidigung und ist
nicht mit der hier beschriebenen Heilungskraft zu verwechseln.

## Zufall und Reproduzierbarkeit

- Die Schadensschwankung des Spielers beträgt bei jeder Aktion `-2...2`.
- Die Angriffsschwankung des Gegners beträgt bei jeder Aktion `-2...2`.
- Opportunist wird ausgelöst, wenn aus `0...3` die 0 fällt, also mit genau 25% Wahrscheinlichkeit.
- Jeder Gegner hat ein geordnetes Absichtsmuster. Der Seed wählt dessen Startposition; danach wird
  das vorgegebene Muster wiederholt. Mehrfache Einträge lassen eine Absicht häufiger erscheinen,
  ohne eine zusätzliche verborgene Zufallsentscheidung einzuführen.
- Bei identischem vollständigem Kampfzustand führen dieselbe Katze und dieselbe Aktion zum selben
  Ergebnis. Stimmen Seed, Abschnitt und Runde überein, sind auch beide Schadensschwankungen, die
  Opportunist-Prüfung und die Reihenfolge der Gegnerabsichten gleich.
- Abgelehnte Aktionen, das Ausblenden eines Fensters, der Neuaufbau der UI und Wartezeit verändern
  weder Zufall noch Kampfzustand.
- Es gibt weder Echtzeitlimit noch automatische Züge, Leerlauf- oder Offline-Fortschritt.

## Routen und Abschnitte

Jede Route besteht fest aus 2 Gefechten und 1 Bosskampf. Für die Gefechte gelten jeweils 3 Züge,
für den Bosskampf 5. Die produktiven Routen definieren jeden Gegner einzeln; frühere Abschnitte
werden nicht mehr als Bruchteil der Boss-Kampfkraft erzeugt. Die gegnerische Kampfkraft `P` wird
auf `1...1000`, ausdrücklich angegebene maximale HP auf `1...2000` begrenzt. Der
Kompatibilitäts-Initialisierer setzt HP weiterhin standardmäßig auf `2P`, doch die folgenden sechs
Routen geben die HP ausdrücklich an.

| Route | Affinität | Mindestlevel | Schwierigkeit | XP-Multiplikator |
|---|---|---:|---|---:|
| Sonnenwaldpfad | Morgen | 1 | Einfach | 100% |
| Signaldächer | Abend | 1 | Normal | 100% |
| Mitternachtsarchiv | Nacht | 1 | Normal | 100% |
| Garten im Morgengrauen | Morgengrauen | 2 | Normal | 115% |
| Mittagsbahnhof | Nachmittag | 4 | Schwer | 130% |
| Labor der tiefen Nacht | Tiefe Nacht | 6 | Experte | 130% |

Die Schwierigkeit ist eine beschreibende Routenangabe und wendet keine weitere verborgene
Skalierungsformel an. Eine gesperrte Route ist in der Auswahl als Vorschau sichtbar, kann aber erst
ab dem erforderlichen Abenteuerlevel gestartet werden. Stempel und Abschlüsse schalten keine
Routen frei.

In den folgenden Mustern steht `H` für Schwerer Hieb, `G` für Abwehrhaltung und `D` für Zehrender
Nebel. Die angegebene Reihenfolge wird wiederholt; der Seed kann ihren ersten Eintrag verschieben.

| Route | Abschnitt und Gegner | `P / HP` | Absichtsmuster |
|---|---|---:|---|
| Sonnenwaldpfad | 1 · Moosspäher | 34 / 72 | `H-G-D` |
| Sonnenwaldpfad | 2 · Pollenschelm | 43 / 88 | `G-D-H` |
| Sonnenwaldpfad | Boss · Sonnenstrahlwächter | 60 / 124 | `H-H-G-D` |
| Signaldächer | 1 · Kabelspatz | 36 / 72 | `G-G-H` |
| Signaldächer | 2 · Neonstreuner | 45 / 94 | `G-H-D` |
| Signaldächer | Boss · Signalwächter | 64 / 132 | `G-G-D-H` |
| Mitternachtsarchiv | 1 · Staubgeist | 38 / 68 | `D-D-G` |
| Mitternachtsarchiv | 2 · Tintenschatten | 48 / 84 | `D-H-D` |
| Mitternachtsarchiv | Boss · Archivwächter | 68 / 120 | `D-D-H` |
| Garten im Morgengrauen | 1 · Taugeist | 39 / 72 | `H-D-H` |
| Garten im Morgengrauen | 2 · Glasflügler | 50 / 96 | `H-H-G` |
| Garten im Morgengrauen | Boss · Morgenblüte | 72 / 142 | `H-D-H` |
| Mittagsbahnhof | 1 · Bahnsteigfunke | 40 / 82 | `G-G-D` |
| Mittagsbahnhof | 2 · Uhrwerk-Rivale | 51 / 106 | `G-H-D` |
| Mittagsbahnhof | Boss · Bahnhofswächter | 74 / 150 | `G-G-H-D` |
| Labor der tiefen Nacht | 1 · Störsignalgeist | 42 / 84 | `D-H-D-G` |
| Labor der tiefen Nacht | 2 · Schlafender Prozess | 54 / 110 | `H-D-G-D` |
| Labor der tiefen Nacht | Boss · Kernel-Wächter | 78 / 158 | `D-H-G-D` |

### Sieg, Niederlage und Abschnittswechsel

- Sinken die Gegner-HP auf 0, ist der Kampf sofort gewonnen.
- Sinken die Gruppen-HP auf 0, ist er verloren.
- Lebt der Gegner nach dem letzten erlaubten Zug noch, ist der Kampf verloren.
- Wird der Gegner im letzten Zug besiegt, hat der Sieg Vorrang vor einer Niederlage durch das
  Zuglimit.
- Eine Niederlage in einem Gefecht beendet sofort die gesamte Expedition.
- Gruppen-HP und Mana werden mit den Werten vor dem Relikteffekt in den nächsten Abschnitt
  übernommen. Warm Tea (Warmer Tee) verändert anschließend die HP, Mana Bell (Managlocke)
  aktuelles und maximales Mana, bevor der nächste Kampf beginnt.
- Zwischen den Abschnitten gibt es keine automatische vollständige Heilung.

## Mana

| Punkt | Regel |
|---|---|
| Startmana | 2 |
| Grundwert für maximales Mana | 3 |
| Standardangriff | Mana `+1`, höchstens bis zum Maximum |
| Rollenfähigkeit | Mana `-1` |
| Rollenfähigkeit bei 0 Mana | Aktion wird abgelehnt |
| Abschnittswechsel | Aktuelles Mana bleibt erhalten |
| Maximum nach Erhalt der Managlocke | 4 |

Das verbleibende Mana ist Teil des Ergebniszustands, fließt jedoch weder in Punktzahl noch XP ein.

## Relikte

Nach jedem Sieg im ersten und zweiten Gefecht werden 3 noch nicht besessene Relikte angeboten.
Eines davon muss gewählt werden, bevor der nächste Kampf beginnt.

- Es gibt insgesamt 6 Relikte.
- Dasselbe Relikt kann nicht mehrfach erhalten werden.
- Beim Erreichen des Bosskampfs besitzt die Gruppe 2 Relikte.
- Das Angebot wird vom Expeditions-Seed und vom Abschnitt bestimmt.
- Sämtliche Relikte gelten nur für die laufende Expedition und werden nicht dauerhaft gespeichert.

| Relikt | Genaue Wirkung |
|---|---|
| Sharpened Claw (Geschärfte Kralle) | Versuchter Schaden aller Standardangriffe und Rollenfähigkeiten `+4` |
| Padded Cape (Gepolsterter Umhang) | Schadensminderung gegen Gegenangriffe `+4` |
| Mana Bell (Managlocke) | Maximales Mana `+1`, beim Auswählen sofort aktuelles Mana `+1` |
| Warm Tea (Warmer Tee) | Heilt sofort um `max(1, HPmax / 5)`, nicht über die maximalen HP hinaus |
| Echo Charm (Echoamulett) | Nach der grundlegenden Manaänderung der Aktion Mana `+1`, wenn eine Gegnerabsicht gekontert wurde |
| Healing Herb (Heilkraut) | Mögliche Heilung der Unterstützer-Rollenfähigkeit `+8` |

Wird mit dem Echoamulett und einer Rollenfähigkeit erfolgreich gekontert, kann der Verbrauch von
1 Mana-Punkt ausgeglichen werden. Hat ein konternder Standardangriff das Mana bereits auf das
Maximum gebracht, wird es nicht darüber hinaus erhöht.

## Abschlusspunktzahl und Ergebnisrang

Bei Niederlage oder Rückzug ist die Punktzahl immer 0. Nur nach einem Sieg über den Boss gilt die
folgende Formel.

```text
HP-Punkte = verbleibende Gruppen-HP × 25 / maximale Gruppen-HP
Konterpunkte = erfolgreiche Konter × 20 / alle Aktionen
Effizienzpunkte = max(0, 10 - 3 × max(0, alle Aktionen - 8))

Endpunktzahl = min(100, 40 + HP-Punkte + Konterpunkte + Effizienzpunkte)
```

Bei jeder Division wird der Nachkommateil verworfen.

| Bestandteil der Punktzahl | Maximum |
|---|---:|
| Grundwert für den Abschluss | 40 |
| Anteil verbleibender HP | 25 |
| Anteil erfolgreicher Konter | 20 |
| Zugeffizienz | 10 |
| Maximum der aktuellen Implementierung | 95 |

| Gesamtzahl der Aktionen | Effizienzpunkte |
|---:|---:|
| 8 oder weniger | 10 |
| 9 | 7 |
| 10 | 4 |
| 11 | 1 |

| Ergebnisrang | Bedingung |
|---|---:|
| S | Abschlusspunktzahl 90 oder höher |
| A | Abschlusspunktzahl 85~89 |
| B | Abschlusspunktzahl 75~84 |
| C | Abschlusspunktzahl 74 oder niedriger |
| D | Niederlage oder Rückzug |

Da in den drei Abschnitten höchstens 11 Aktionen möglich sind, liegt die praktisch erreichbare
Abschlusspunktzahl bei `41...95`. Mit der aktuellen Rangwertung kann ein abgeschlossener Lauf
keinen D-Rang erhalten. In der Engine bleibt ein Zweig mit 40 XP für einen abgeschlossenen
D-Rang bestehen, ist unter der derzeitigen Rangwertung jedoch nicht erreichbar.

Die Punkteformel liest weder das abschließend verbleibende Mana noch die Anzahl der Relikte direkt.
Manaverwaltung und ausgewählte Relikte können das Kampfergebnis und damit die Punktzahl dennoch
indirekt beeinflussen. Das gilt auch für:

- die eigens definierten Gegner, HP, Absichtsmuster und feste Schwierigkeit der gewählten Route
- den Seltenheitsrang der Katzen und die Zusammenstellung ihrer Rollen

Das Abenteuerlevel bestimmt, welche Route gestartet werden kann, wird nach der Auswahl aber weder
von Kampf noch Punkteberechnung gelesen. Bindung und Routenstempel haben derzeit weder direkten
noch indirekten Einfluss auf Kampf oder Punktzahl.

## XP und dauerhafte Belohnungen

### Abschluss

| Ergebnisrang | Basis-Abenteuer-XP | Stempel der gewählten Route | Bindung der teilnehmenden Katzen |
|---|---:|---:|---:|
| S | 120 | +1 | jeweils +1 |
| A | 100 | +1 | jeweils +1 |
| B | 80 | +1 | jeweils +1 |
| C | 60 | +1 | jeweils +1 |
| D-Zweig | 40 | +1 | jeweils +1 |

Bei einem Abschluss erhöht sich auch die Gesamtzahl der Abschlüsse um 1. Der Belohnungszweig für
einen Abschluss mit D-Rang ist derzeit nicht erreichbar.

Der Routenmultiplikator gilt für jede positive XP-Vergabe, einschließlich der Teil-XP nach einer
Niederlage:

```text
Vergebene Abenteuer-XP = Basis-Abenteuer-XP × Routenmultiplikator / 100
```

Bei der Ganzzahldivision wird der Rest verworfen. So werden aus 20 Basis-XP auf der Route
„Garten im Morgengrauen“ 23 und auf einer 130%-Route 26. Stempel und Bindung werden nicht
multipliziert.

### Niederlage und Rückzug

```text
XP bei Niederlage = vor der Niederlage gewonnene Kämpfe × 10
```

| Ergebnis | Basis-Abenteuer-XP | Stempel | Bindung |
|---|---:|---:|---:|
| Niederlage im ersten Gefecht | 0 | 0 | 0 |
| Niederlage nach 1 gewonnenem Gefecht | 10 | 0 | 0 |
| Niederlage im Bosskampf nach 2 gewonnenen Gefechten | 20 | 0 | 0 |
| Rückzug zu beliebigem Zeitpunkt | 0 | 0 | 0 |

Ein Rückzug gibt immer 0 XP, auch wenn zuvor Gefechte gewonnen wurden. Eine eindeutige
Vergabe-ID je Expedition und die jüngsten Vergabedatensätze verhindern, dass dasselbe Ergebnis
mehrfach angewendet wird.

## Abenteuer-XP und Level

```text
Abenteuerlevel = gesammelte Abenteuer-XP / 250 + 1
XP im aktuellen Level = gesammelte Abenteuer-XP % 250
XP pro Level = 250
```

| Gesammelte XP | Abenteuerlevel |
|---:|---:|
| 0~249 | 1 |
| 250~499 | 2 |
| 500~749 | 3 |
| 750~999 | 4 |
| Danach | Steigt weiterhin alle 250 XP |

Das Level hat derzeit keine Obergrenze. Level und XP-Fortschritt erscheinen in der Oberfläche und
schalten folgende Routen frei:

| Abenteuerlevel | Neu verfügbare Route |
|---:|---|
| 1 | Sonnenwaldpfad, Signaldächer und Mitternachtsarchiv |
| 2 | Garten im Morgengrauen |
| 4 | Mittagsbahnhof |
| 6 | Labor der tiefen Nacht |

Folgende Wirkungen sind **nicht implementiert**:

- Erhöhung von Angriff, maximalen HP, Verteidigung, Schadensminderung oder Heilung
- Erhöhung des maximalen Manas
- Skalierung von Werten, gegnerischer Kampfkraft oder Gegner-HP durch das Abenteuerlevel
- Freischaltung von Relikten, Fähigkeiten oder anderen Funktionen

Das Abenteuerlevel ist somit Fortschritt und Zugangsvoraussetzung für Routen. Es verändert weder
Gruppenwerte, Mana, Gegnerwerte noch die Punkteformel direkt. Höhere XP-Multiplikatoren gehören zu
den ausgestalteten Routen und sind keine allgemeine Skalierung durch das Level.

## Routenstempel und Katzenbindung

### Routenstempel

- Nur die abgeschlossene Route erhält 1 Stempel; sie werden je Route gesammelt.
- Die Anzahl je Route ist in der Oberfläche sichtbar.
- Derzeit gibt es weder Bonus, Verwendung noch Freischaltbedingung.

### Katzenbindung

- Bei einem Abschluss erhält jede der drei teilnehmenden Katzen 1 Punkt.
- Die Punkte werden nach der ursprünglichen Aktivitätsdatums-ID der Katze gesammelt und
  gespeichert.
- Bei Niederlage oder Rückzug gibt es keine Punkte.
- Derzeit gibt es weder eine Anzeige des Werts noch Bindungslevel, Werteboni oder freischaltbare
  Fähigkeiten.
- Wird der ursprüngliche Tageseintrag gelöscht, wird auch die Bindung dieser Katze entfernt.

## Speicherung und Zurücksetzen

Der Abenteuerfortschritt wird getrennt von den bestehenden Aktivitätsstatistiken als JSON in
Pawprints SQLite-Speicher abgelegt.

| Dauerhaft gespeicherter Wert | Inhalt |
|---|---|
| Gesammelte Abenteuer-XP | Gespeichert |
| Gesamtzahl der Abschlüsse | Gespeichert |
| Stempel je Route | Gespeichert |
| Bindung je Katze | Gespeichert |
| IDs zur Verhinderung doppelter Vergaben | Die IDs der letzten 256 positiven Vergaben werden gespeichert |

| Nicht dauerhaft gespeicherter Wert | Folge |
|---|---|
| Laufende Expedition und aktueller Abschnitt | Nach einem Neustart der App nicht wiederhergestellt |
| Aktuelle HP, Mana und Relikte | Nach einem Neustart der App nicht wiederhergestellt |
| Kampfprotokoll, Zugverlauf und Expeditions-Seed | Nach einem Neustart der App nicht wiederhergestellt |
| Gruppen- und Routenentwurf für die nächste Expedition | Nach einem Neustart der App nicht wiederhergestellt |

Der genaue Speicherort ist der Schlüssel `adventure_progress_v1` in der Tabelle `app_settings`.
Existieren Daten einer frühen Entwicklungsversion in den UserDefaults, aber keine SQLite-Daten,
werden sie einmalig migriert.

- Wird ein bestimmter Tageseintrag gelöscht, werden die Bindung dieser Katze und die Katze selbst
  aus den Expeditionskandidaten entfernt. Gehört sie zur aktuellen Gruppe, endet auch die laufende
  Expedition.
- Bei einer Bereinigung nach der Aufbewahrungsfrist werden ebenfalls Bindungen und Kandidaten
  außerhalb der Frist gelöscht; eine aktive Expedition mit einer betroffenen Katze endet. Die
  gesammelten XP, die Gesamtzahl der Abschlüsse, Routenstempel und IDs gegen doppelte Vergaben
  bleiben erhalten.
- Beim Löschen sämtlicher Daten werden XP, Abschlüsse, Stempel, Bindungen und Vergabedatensätze
  vollständig zurückgesetzt.
- Wird nur der Zustand der aktiven Expedition geschlossen oder zurückgesetzt, bleibt bereits
  vergebener dauerhafter Fortschritt erhalten.

## Derzeit nicht implementierte Erweiterungen

| Element | Aktueller Stand |
|---|---|
| Wertewachstum nach Level | Nicht vorhanden |
| Bindungswirkung und -anzeige | Nur der gespeicherte Zähler ist vorhanden |
| Stempelbelohnungen, -verbrauch oder -freischaltungen | Nicht vorhanden |
| Zahlenbonus für eine Gruppe aus allen 3 Rollen | Nicht vorhanden |
| Steigende Gegnerschwierigkeit nach Level | Nicht vorhanden |
| Dauerhaftes Relikt-, Ausrüstungs- oder Gegenstandsinventar samt Aufwertung | Nicht vorhanden |
| Speichern und Wiederherstellen einer laufenden Expedition | Nicht vorhanden |
| Leerlauf-, Offline- oder Hintergrundfortschritt | Nicht vorhanden |

## Hinweis zum Implementierungsumfang

`AdventureEngine.resolve()` enthält für Kompatibilitäts-APIs und Tests weiterhin die Formeln des
ursprünglichen automatischen Kampfes über 3 Runden. Die aktuelle produktive Abenteueroberfläche
ruft diese API nicht auf. Die Kampfregeln dieses Dokuments beziehen sich ausschließlich auf
`AdventureEngine.performTurn()` und `AdventureExpeditionEngine`, die von der tatsächlichen
Oberfläche verwendet werden.

## Maßgebliche Codebereiche

- [AdventureEngine.swift](../Sources/PawprintCore/Engine/AdventureEngine.swift): Katzenwerte,
  Aktionen, Schaden, Verteidigung, Heilung, Passivfähigkeiten sowie gegnerspezifische HP und
  Absichtsmuster
- [AdventureExpeditionEngine.swift](../Sources/PawprintCore/Adventure/AdventureExpeditionEngine.swift):
  Expedition mit 3 Kämpfen, Mana, Relikte, Punkte, Ränge und XP-Belohnungen mit Routenmultiplikator
- [PawpetAdventureAdapter.swift](../Sources/Pawprint/Adventure/PawpetAdventureAdapter.swift):
  Verbindung zwischen Pawpet-Aussehen und RPG-Eigenschaften
- [AdventureRosterCatalog.swift](../Sources/Pawprint/Adventure/AdventureRosterCatalog.swift):
  Regeln für teilnehmende Kandidaten
- [AdventureExpeditionCenter.swift](../Sources/Pawprint/Adventure/AdventureExpeditionCenter.swift):
  sechs ausgestaltete Routen, Levelgrenzen, Gruppenentwurf und Lebenszyklus der aktiven Expedition
- [AdventureRewardStore.swift](../Sources/Pawprint/Adventure/AdventureRewardStore.swift):
  Speicherung von XP, Level, Stempeln und Bindung
- [PawprintStore.swift](../Sources/PawprintCore/Storage/PawprintStore.swift):
  SQLite-Speicherort und Lebenszyklus sämtlicher Daten
- [PawpetTraits.swift](../Sources/Pawprint/UI/Components/PawpetTraits.swift):
  Berechnung von Seltenheitsrang und Aura
- [CatLustre.swift](../Sources/PawprintCore/Engine/CatLustre.swift): Berechnung des
  Pawpet-Aktivitätsaufwands
