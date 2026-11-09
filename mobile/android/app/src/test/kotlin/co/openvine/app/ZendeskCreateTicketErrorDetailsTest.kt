package co.openvine.app

import com.zendesk.service.ErrorResponse
import com.zendesk.service.Header
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The details Dart receives when the Zendesk SDK rejects a ticket. Dart
 * retries `authFailed` with another identity and keeps `networkError` out of
 * crash reports, so a wrong flag either loses the ticket or floods reports.
 */
class ZendeskCreateTicketErrorDetailsTest {
    private fun errorResponse(
        reason: String,
        status: Int,
        networkError: Boolean = false,
    ): ErrorResponse = @Suppress("OVERRIDE_DEPRECATION") object : ErrorResponse {
        override fun isNetworkError() = networkError
        override fun isConversionError() = false
        override fun isHttpError() = status != ErrorResponse.NON_HTTP_ERROR
        override fun getReason() = reason
        override fun getStatus() = status
        override fun getUrl() = ""
        override fun getResponseBody() = ""
        override fun getResponseBodyType() = ""
        override fun getResponseHeaders() = emptyList<Header>()
    }

    @Test
    fun `flags the SDK's failed token exchange as an auth failure`() {
        // The SDK's synthetic response when our JWT endpoint rejects the token.
        val details = zendeskCreateTicketErrorDetails(
            errorResponse("Response body was null, failed to auth user.", 400),
        )

        assertEquals(
            mapOf("status" to 400, "networkError" to false, "authFailed" to true),
            details,
        )
    }

    @Test
    fun `marks an offline token exchange as a network error, not an auth failure`() {
        // The SDK's synthetic response when the token exchange hits an I/O error.
        val details = zendeskCreateTicketErrorDetails(
            errorResponse("Response was null, failed to auth user.", 400),
        )

        assertEquals(
            mapOf("status" to 400, "networkError" to true, "authFailed" to false),
            details,
        )
    }

    @Test
    fun `does not mistake a bare null response for an offline token exchange`() {
        val details = zendeskCreateTicketErrorDetails(
            errorResponse("Response was null", 400),
        )

        assertEquals(
            mapOf("status" to 400, "networkError" to false, "authFailed" to false),
            details,
        )
    }

    @Test
    fun `flags a rejected token exchange response as an auth failure`() {
        val details = zendeskCreateTicketErrorDetails(
            errorResponse("Response was 409, failed to auth user.", 400),
        )

        assertEquals(
            mapOf("status" to 400, "networkError" to false, "authFailed" to true),
            details,
        )
    }

    @Test
    fun `flags an identity of the wrong type as an auth failure`() {
        val details = zendeskCreateTicketErrorDetails(
            errorResponse(
                "The expected type of authentication is jwt. " +
                    "The local identity is not present.\n",
                400,
            ),
        )

        assertEquals(true, details["authFailed"])
    }

    @Test
    fun `flags a 401 as an auth failure`() {
        val details = zendeskCreateTicketErrorDetails(errorResponse("401", 401))

        assertEquals(true, details["authFailed"])
    }

    @Test
    fun `does not flag a rejected request as an auth failure`() {
        val details = zendeskCreateTicketErrorDetails(
            errorResponse("Unprocessable Entity", 422),
        )

        assertEquals(
            mapOf("status" to 422, "networkError" to false, "authFailed" to false),
            details,
        )
    }

    @Test
    fun `marks an I-O failure as a network error`() {
        val details = zendeskCreateTicketErrorDetails(
            errorResponse("timeout", ErrorResponse.NON_HTTP_ERROR, networkError = true),
        )

        assertEquals(
            mapOf("status" to -1, "networkError" to true, "authFailed" to false),
            details,
        )
    }

    @Test
    fun `treats a missing error as an unknown failure`() {
        assertEquals(
            mapOf("status" to -1, "networkError" to false, "authFailed" to false),
            zendeskCreateTicketErrorDetails(null),
        )
    }
}
