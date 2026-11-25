from zoneinfo import available_timezones

CONTINENTES_VALIDOS = {
    "Africa", "America", "Antarctica", "Asia", "Atlantic",
    "Australia", "Europe", "Indian", "Pacific"
}

FUSOS_HORARIOS = sorted(
    (nome, nome.replace("_", " "))
    for nome in available_timezones()
    if nome.split("/")[0] in CONTINENTES_VALIDOS
)