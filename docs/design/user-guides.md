# User guides

Travelers write destination guides with the existing rich document editor, categories, place cards, cover selection and map. A draft is private to its author. Publishing makes it readable in Explore and in trips visiting its country. Admin city guides keep their current itinerary placement and API.

## Design contract

Use the existing Plus Jakarta Sans for headings and reading text. Left-align the content. Keep Navio's semantic tokens: paper (#FFFFFF), ink (#172638), blue (#2589EC), muted surface (#F1F3F7), border (#D3D9E2), and teal (#338F86); these are reference swatches, with actual light/dark values inherited from globals.css. Cover photography carries the visual character. Avoid a decorative hero, extra statistics and repeated framed panels.

The dashboard places Your Guides immediately below Explore plans, followed by Explore guides. A quiet author workspace pairs a clear Write a guide action with cover thumbnails, destination labels, Draft/Published badges and edit links. Public cards emphasize the author's title, destination, byline and number of places. Search uses a labeled shadcn Input; filters, loading, retry and pagination are explicit. The shared editor retains shadcn buttons, menus, dialogs, sheets and its mobile map.

```text
Dashboard                     Explore
Explore plans                 Explore plans and guides
Your Guides   Write a guide   Search city, country or title
[cover / title / status]      [Plans] [Guides]
Explore guides                [cover / title / city / author]
[cover / city / author]       Load more

Your Guides                   Reading a guide
Title + Write a guide         Back to guides
Search your library           Cover / title / city / author
[cover / title / status]      Categories / authored document
                              Cover title + author avatar | fixed map
                              Section shortcuts / authored cards | place preview
                              Resize divider; Guide/Map on mobile
```

Review: a large promotional header and identical dashboard boxes would compete with the trip cards. Use open sections and compact author rows instead. Country/city search is handled by the backend across the entire public collection; trip discovery groups destinations by country and includes guides for every city in those countries; missing-country data retains a city match. Keep page files as composition, reusable discovery/card/library widgets in app/feature/guides, and extend the existing editor through a typed workspace adapter.

## Persistence

User Management owns iam.user_guides (V8). Each row has a required owner UUID, the same authored document fields as iam.guides, optimistic version, publication state and timestamps. The existing iam.guides table and destination uniqueness stay unchanged. Owner-only routes are /v1/users/me/guides; published discovery is /v1/traveler-guides. Public responses expose the author's existing public profile UUID, display name and current avatar reference, never an email or authentication subject. The Next.js proxies restrict methods and path segments. Lists are paginated and public search covers title, destination and country.

The traveler and Navio team readers share the photo cover with overlaid location, title and byline, section headings/counts, place cards and live map preview. Traveler bylines show the saved profile picture, with initials when absent or unavailable; discovery cards use the same byline component. The document uses the panel width with ordinary reading-length prose. Desktop defaults to a 65% document with a resizable map; the saved divider preference remains respected. On mobile, a card opens Map and its preview, while marker selection and Previous/Next keep the map visible. Guide/Map controls preserve selection and the reading position. Preview content scrolls within the map on short screens.
