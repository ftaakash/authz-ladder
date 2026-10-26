// Pilot 08 KC2 — assembles two Eclipse identity runtimes as fat jars from released
// Maven Central BOMs (local testbed only). One jar runs an IdentityHub (embedded STS +
// credential/presentation service + did:web publisher + identity API for seeding); the
// other runs an IssuerService (trusted issuer that issues MembershipCredentials).
// Version pinned to the Tractus-X 0.13.0 connector's bundled EDC (0.17.0). See D10.
//
// The identityhub role also compiles a minimal KC2 seed ServiceExtension (src/main/java,
// pilot08kc2.Kc2SeedExtension) that creates one configured participant context at startup so a
// did:web document exists to resolve. The issuer role excludes that source and its SPI deps, so
// its runtime never loads an extension referencing IdentityHub-only classes.
//
// Build:  gradle shadowJar -Prole=identityhub   (or -Prole=issuer), inside the pinned
//         gradle container (scripts mirror KC1's 30_build_vanilla.sh).
plugins {
    application
    id("com.gradleup.shadow") version "8.3.5"
}
repositories { mavenCentral() }

val edc = (project.findProperty("edc") as String?) ?: "0.17.0"
val role = (project.findProperty("role") as String?) ?: "identityhub"
fun edc(m: String) = "org.eclipse.edc:$m:$edc"

dependencies {
    when (role) {
        "identityhub" -> {
            runtimeOnly(edc("identityhub-bom"))
            // the participant-config store encrypts entries with "aes" by default, but the BOM
            // ships no encryption algorithm provider; add the official AES one (local testbed).
            runtimeOnly(edc("aes-encryption"))
            // compile-only SPI for the seed extension (these classes are already on the
            // identityhub runtime classpath via the BOM, so they are not bundled again)
            compileOnly(edc("core-spi"))
            compileOnly(edc("participant-context-spi"))
            compileOnly(edc("verifiable-credential-spi"))          // CredentialStore, VerifiableCredentialResource/Container
            compileOnly(edc("verifiable-credentials-spi"))         // VerifiableCredential, CredentialSubject, Issuer, CredentialFormat
            compileOnly(edc("identity-did-spi"))                   // Service (DID document CredentialService endpoint)
            compileOnly("com.nimbusds:nimbus-jose-jwt:10.8")       // VC-JWT signing (runtime copy comes from the BOM)
        }
        "issuer"      -> runtimeOnly(edc("issuerservice-bom"))
        else -> throw GradleException("unknown role=$role (identityhub|issuer)")
    }
}

// Only the identityhub role includes the seed extension source + its service registration.
sourceSets {
    main {
        if (role != "identityhub") {
            java { setSrcDirs(emptyList<String>()) }
            resources { setSrcDirs(emptyList<String>()) }
        }
    }
}
application { mainClass.set("org.eclipse.edc.boot.system.runtime.BaseRuntime") }
tasks.shadowJar {
    mergeServiceFiles()
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
    archiveFileName.set("pilot08kc2-${role}-all.jar")
}
