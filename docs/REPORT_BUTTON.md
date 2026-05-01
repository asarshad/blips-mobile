# Report Button

The `Report` button lets a user flag content or an AI chat response for moderation review.

## Where It Appears

- Article cards
- Video cards
- Reel action menu
- AI chat responses

## User Flow

1. The user taps `Report`.
2. The app opens a bottom sheet asking: `What's wrong with this content?`
3. The user selects one reason.
4. The app submits the report to the backend.
5. The user sees either:
   - `Thanks - we'll review this content.`
   - `Couldn't submit your report. Please try again.`

For AI chat responses, the success message says:

`Thanks - we'll review this response.`

## Report Reasons

The app currently sends one of these reason keys:

- `hateful` - Hateful or discriminatory
- `violence` - Promotes violence or self-harm
- `explicit` - Sexually explicit content
- `spam` - Spam or misleading
- `misinformation` - Dangerous misinformation
- `other` - Other

## What Gets Sent

The app posts to:

```text
POST /api/v1/session/reports
```

Payload:

```json
{
  "content_item_id": 123,
  "surface": "articles | videos | reels | chat",
  "reason": "spam",
  "message_id": "optional-chat-message-id"
}
```

`message_id` is only included for AI chat response reports.

## What The Backend Does

The backend stores the report in the `content_reports` table with:

- reporting device ID
- content item ID
- surface
- reason
- optional chat message ID
- `reviewed = false`
- creation timestamp

The report does not automatically remove the item from everyone else's feed.

## Related Behavior: Block Source

`Block Source` is separate from `Report`.

When a user blocks a source:

- The source is hidden locally for that user.
- The app records a `LESS_FROM_CREATOR` interaction.
- The app also sends a moderation report with reason `blocked_source`.

This gives us an audit trail that the user blocked the source, but it is not the same as choosing a report reason from the report sheet.

## Current Limitations

- Reports are stored for operator review, but there is no automatic moderation action.
- The user cannot type custom details for `other`.
- The app does not currently expose a report history to the user.
