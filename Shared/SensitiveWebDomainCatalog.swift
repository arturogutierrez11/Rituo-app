import ManagedSettings

enum SensitiveWebDomainCatalog {
    private static let maximumManagedDomains = 50

    static let blockedDomains: Set<WebDomain> = {
        var seenDomainNames = Set<String>()
        let uniqueDomainNames = domainNames.filter {
            seenDomainNames.insert($0).inserted
        }

        guard uniqueDomainNames.count <= maximumManagedDomains else {
            assertionFailure(
                "ManagedSettings admite hasta \(maximumManagedDomains) dominios; se configuraron \(uniqueDomainNames.count)."
            )
            return Set(
                uniqueDomainNames.prefix(maximumManagedDomains)
                    .map(WebDomain.init(domain:))
            )
        }

        return Set(uniqueDomainNames.map(WebDomain.init(domain:)))
    }()

    static let safariContentBlockerDomainPatterns = domainNames.map { "*\($0)" }

    private static let socialDomainRoots = [
        "facebook.com",
        "instagram.com",
        "threads.net",
        "x.com",
        "twitter.com",
        "tiktok.com",
        "youtube.com",
        "reddit.com",
        "snapchat.com",
        "twitch.tv",
        "kick.com",
        "linkedin.com",
        "pinterest.com",
        "tumblr.com",
        "discord.com",
        "bsky.app"
    ]

    private static let bettingDomainRoots = [
        "bet365.com",
        "bet365.com.ar",
        "bet365.bet.ar",
        "betano.com",
        "betano.bet.ar",
        "betsson.com",
        "betsson.bet.ar",
        "codere.com.ar",
        "codere.bet.ar",
        "bplay.com.ar",
        "bplay.bet.ar",
        "betwarrior.bet.ar",
        "sportbet.bet.ar",
        "stake.com",
        "bwin.com",
        "pokerstars.com",
        "1xbet.com",
        "sportingbet.com",
        "betway.com",
        "rivalo.com",
        "playuzu.com",
        "betfair.com",
        "williamhill.com",
        "unibet.com"
    ]

    private static let requiredAliases = [
        "t.co",
        "youtu.be",
        "vm.tiktok.com",
        "m.facebook.com",
        "m.instagram.com",
        "m.tiktok.com"
    ]

    private static let domainNames =
        socialDomainRoots + bettingDomainRoots + requiredAliases
}
