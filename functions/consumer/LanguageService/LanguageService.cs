using Google.Cloud.Language.V1;

namespace Consumer;

public class LanguageService : ILanguageService
{
    public async Task<float> GetSentimentAsync(string text, CancellationToken cancellationToken = default)
    {
        var client = await LanguageServiceClient.CreateAsync(cancellationToken);
        var sentiment = await client.AnalyzeSentimentAsync(new Document()
        {
            Content = text,
            Type = Document.Types.Type.PlainText
        }, cancellationToken);

        return sentiment.DocumentSentiment.Score;
    }
}
