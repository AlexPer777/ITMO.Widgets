package dev.alllexey.itmowidgets.ios.bridge

import dev.alllexey.itmowidgets.core.result.AppError
import dev.alllexey.itmowidgets.core.result.AppResult
import dev.alllexey.itmowidgets.feature.social.domain.PersonRepository
import dev.alllexey.itmowidgets.feature.social.domain.model.Person
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest

class TeacherPhotoLoaderTest {
    @Test
    fun repeatedRowsUseOneDirectoryRequestAndReuseTheCachedPhoto() = runTest {
        val people = People()
        val loader = TeacherPhotoLoader(people)
        val photos = List(12) { async { loader.photoUrl(123) } }.awaitAll()
        assertEquals(List(12) { "https://example.test/123.jpg" }, photos)
        assertEquals(1, people.calls)
        assertEquals(photos.first(), loader.cachedPhotoUrl(123))
    }

    @Test
    fun openingManyTeachersLimitsRequestsAndMissingPhotosStayCached() = runTest {
        val people = People(noPhoto = true)
        val loader = TeacherPhotoLoader(people)
        (1..20).map { async { loader.photoUrl(it) } }.awaitAll()
        assertEquals(4, people.peak)
        assertNull(loader.photoUrl(1))
        assertEquals(20, people.calls)
    }

    @Test
    fun invalidIdsAndNetworkFailuresKeepTheInitialsAndAFailureCanRetry() = runTest {
        val people = People(fail = true)
        val loader = TeacherPhotoLoader(people)
        assertNull(loader.photoUrl(0))
        assertEquals(0, people.calls)
        assertNull(loader.photoUrl(1))
        people.fail = false
        assertEquals("https://example.test/1.jpg", loader.photoUrl(1))
        assertEquals(2, people.calls)
    }

    private class People(val noPhoto: Boolean = false, var fail: Boolean = false) : PersonRepository {
        val cache = mutableMapOf<Int, Person>()
        var calls = 0
        var active = 0
        var peak = 0
        override fun cachedPerson(isu: Int) = cache[isu]
        override suspend fun person(isu: Int): AppResult<Person> {
            calls++
            active++
            peak = maxOf(peak, active)
            try {
                delay(10)
                if (fail) return AppResult.Failure(AppError.Network)
                val person = Person(isu, "Teacher", if (noPhoto) null else "https://example.test/$isu.jpg", emptyList(), emptyList(), emptyList())
                cache[isu] = person
                return AppResult.Success(person)
            } finally { active-- }
        }
    }
}
