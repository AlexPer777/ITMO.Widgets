package dev.alllexey.itmowidgets.ios.bridge

import dev.alllexey.itmowidgets.core.demo.DemoMode
import dev.alllexey.itmowidgets.core.session.SessionTokenStore
import dev.alllexey.itmowidgets.core.result.valueOrNull
import dev.alllexey.itmowidgets.feature.social.domain.PersonRepository
import dev.alllexey.itmowidgets.ios.di.IosKoin
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.sync.withPermit

/** Directory photos for teacher rows, without opening a profile or requiring the Backend opt-in. */
object IosTeacherPhotos {
    private val loader by lazy { TeacherPhotoLoader(IosKoin.koin().get()) }

    /** No graph in a standalone view preview: initials only. */
    fun cachedPhotoUrl(isu: Int): String? = if (IosKoin.isStarted) loader.cachedPhotoUrl(isu) else null

    suspend fun photoUrl(isu: Int): String? {
        if (!IosKoin.isStarted) return null
        val koin = IosKoin.koin()
        if (!koin.get<DemoMode>().isActive() && !koin.get<SessionTokenStore>().hasRefreshToken()) return null
        return loader.photoUrl(isu)
    }
}

/** Reuse the session's person cache, coalesce repeated teachers and cap concurrent directory requests. */
internal class TeacherPhotoLoader(private val people: PersonRepository) {
    private val requests = mutableMapOf<Int, Mutex>()
    private val requestsLock = Mutex()
    private val limit = Semaphore(4)

    fun cachedPhotoUrl(isu: Int): String? = people.cachedPerson(isu)?.photoUrl

    suspend fun photoUrl(isu: Int): String? {
        if (isu <= 0) return null
        val lock = requestsLock.withLock { requests.getOrPut(isu) { Mutex() } }
        return lock.withLock {
            // A cached person without a photo is a real answer too: do not request them on each scroll.
            people.cachedPerson(isu)?.let { return@withLock it.photoUrl }
            limit.withPermit { people.person(isu).valueOrNull()?.photoUrl }
        }
    }
}
