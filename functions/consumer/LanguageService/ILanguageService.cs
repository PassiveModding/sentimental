namespace Consumer;

public interface ILanguageService
{
    Task<float> GetSentimentAsync(string text, CancellationToken cancellationToken);
}
