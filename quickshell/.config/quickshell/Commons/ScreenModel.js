function targetScreens(screens, targetName) {
    if (!screens || screens.length === 0) return []
    if (!targetName) return [screens[0]]

    for (var i = 0; i < screens.length; i++) {
        if (screens[i].name === targetName) return [screens[i]]
    }

    return [screens[0]]
}
