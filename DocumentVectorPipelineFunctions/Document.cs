
namespace DocumentVectorPipelineFunctions
{
    public class Document
    {
        public int Id { get; set; }
        public int? ChunkId { get; set; }
        public string DocumentUrl { get; set; }
        public byte[] Embedding { get; set; }
        public string ChunkText { get; set; }
        public int? PageNumber { get; set; }
    }

}
