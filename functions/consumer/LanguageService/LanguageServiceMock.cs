using Google.Cloud.PubSub.V1;

namespace Consumer;

public class LanguageServiceMock : ILanguageService
{
    public Task<float> GetSentimentAsync(string text, CancellationToken cancellationToken = default)
    {
        float result;
        if (text.Contains("bad"))
        {
            result = -1f;
        }
        else if (text.Contains("good"))
        {
            result = 1f;
        }
        else
        {
            result = 0f;
        }

        return Task.FromResult(result);
    }
}
