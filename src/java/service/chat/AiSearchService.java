package service.chat;

import com.fasterxml.jackson.databind.ObjectMapper;
import config.AppConfig;
import dao.catalog.ProductDAO;
import dao.system.SystemConfigDAO;
import model.entity.catalog.Product;
import util.LoggerUtil;

import java.io.IOException;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpTimeoutException;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.logging.Logger;

/**
 * Service AI search gom logic upstream/fallback và response contract ổn định.
 */
// Touched for IDE re-indexing
public class AiSearchService {

    private static final Logger log = Logger.getLogger(AiSearchService.class.getName());

    private static final long TOTAL_BUDGET_MS = 15_000L;
    private static final long UPSTREAM_TIMEOUT_MS = 12_000L;
    private static final long MIN_RETRY_BUDGET_MS = 4_000L;
    private static final int MAX_RETRIES = 1;
    private static final int MAX_FALLBACK_PRODUCTS = 6;
    private static final int MAX_AI_CONTEXT_PRODUCTS = 12;
    private static final Set<Integer> TRANSIENT_AI_STATUS_CODES = Set.of(429, 503);
    private static final Set<Integer> AI_CONFIG_ERROR_STATUS_CODES = Set.of(400, 401, 403, 404);
    private static final Set<String> AI_SEARCH_STOP_WORDS = Set.of(
            "cho", "voi", "cua", "mot", "nhung", "nay", "ban", "toi", "minh", "tu",
            "den", "la", "va", "the", "thi", "duoc", "khong");
    private static final Set<String> VITAMIN_C_HINTS = Set.of(
            "cam", "quyt", "buoi", "kiwi", "dau tay", "oi", "chanh", "cherry", "dua luoi");

    private final ProductDAO productDAO = new ProductDAO();
    private final SystemConfigDAO systemConfigDAO = new SystemConfigDAO();
    private final AiCatalogContextCache catalogContextCache = new AiCatalogContextCache();
    private final ObjectMapper mapper = new ObjectMapper();
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofMillis(1_200))
            .build();

    @FunctionalInterface
    public interface DeltaConsumer {
        void accept(String delta) throws Exception;
    }

    public Map<String, Object> search(String rawUserMessage) throws Exception {
        long startedAt = System.currentTimeMillis();
        String userMessage = normalizeText(rawUserMessage);
        if (userMessage == null || userMessage.isBlank()) {
            throw new IllegalArgumentException("Nội dung tìm kiếm không được để trống.");
        }

        AiCatalogContextCache.Snapshot snapshot = catalogContextCache.getSnapshot();
        String apiKey = resolveApiKey();
        if (apiKey == null) {
            return buildUpstreamErrorResponse(
                    startedAt,
                    "missing_api_key",
                    "Chưa có Gemini API key hợp lệ. Hãy cấu hình trong Admin hoặc biến môi trường GEMINI_API_KEY.",
                    null,
                    null);
        }

        List<Product> promptProducts = selectRelevantProducts(
                userMessage,
                snapshot.getActiveProducts(),
                snapshot.getCategoryNames(),
                MAX_AI_CONTEXT_PRODUCTS);
        String requestBody = mapper.writeValueAsString(buildGeminiPayload(
                userMessage,
                snapshot.getCategories(),
                promptProducts));

        long deadlineAt = startedAt + TOTAL_BUDGET_MS;
        HttpResponse<String> httpResponse = null;
        String failureReason = null;
        String lastErrorBody = null;

        for (int attempt = 0; attempt <= MAX_RETRIES; attempt++) {
            long remainingBudget = deadlineAt - System.currentTimeMillis();
            if (remainingBudget <= 0) {
                failureReason = "budget_exhausted";
                break;
            }
            long timeoutMs = Math.min(UPSTREAM_TIMEOUT_MS, remainingBudget);
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + apiKey))
                    .timeout(Duration.ofMillis(timeoutMs))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody, StandardCharsets.UTF_8))
                    .build();
            try {
                httpResponse = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                failureReason = "interrupted";
                break;
            } catch (HttpTimeoutException hte) {
                failureReason = "timeout";
                LoggerUtil.warn(log, "Gemini API phản hồi quá chậm.", hte);
                long retryBudget = deadlineAt - System.currentTimeMillis();
                if (attempt < MAX_RETRIES && retryBudget >= MIN_RETRY_BUDGET_MS) {
                    continue;
                }
                return buildUpstreamErrorResponse(
                        startedAt,
                        "timeout",
                        "Gemini phản hồi quá lâu. Vui lòng thử lại sau.",
                        null,
                        null);
            } catch (IOException ioe) {
                failureReason = "network_error";
                LoggerUtil.warn(log, "Không gọi được Gemini API.", ioe);
                long retryBudget = deadlineAt - System.currentTimeMillis();
                if (attempt < MAX_RETRIES && retryBudget >= MIN_RETRY_BUDGET_MS) {
                    continue;
                }
                return buildUpstreamErrorResponse(
                        startedAt,
                        "network_error",
                        "Không kết nối được tới Gemini. Vui lòng thử lại sau.",
                        null,
                        null);
            }

            int status = httpResponse.statusCode();
            if (status == 200) {
                try {
                    return buildGeminiResponse(httpResponse.body(), startedAt);
                } catch (Exception parseError) {
                    LoggerUtil.warn(log, "Gemini trả về payload không hợp lệ.", parseError);
                    return buildUpstreamErrorResponse(
                            startedAt,
                            "invalid_gemini_payload",
                            "Gemini trả về dữ liệu không hợp lệ. Vui lòng thử lại sau.",
                            status,
                            truncateForLog(httpResponse.body()));
                }
            }

            lastErrorBody = truncateForLog(httpResponse.body());
            if (AI_CONFIG_ERROR_STATUS_CODES.contains(status)) {
                String errorMessage = extractGeminiErrorMessage(status, lastErrorBody);
                LoggerUtil.warn(log, "Gemini upstream config error status=%d body=%s", status, lastErrorBody);
                return buildUpstreamErrorResponse(
                        startedAt,
                        "http_" + status,
                        errorMessage,
                        status,
                        lastErrorBody);
            }
            if (attempt < MAX_RETRIES && TRANSIENT_AI_STATUS_CODES.contains(status)) {
                failureReason = "retry_" + status;
                try {
                    Thread.sleep(150L);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    failureReason = "interrupted";
                    break;
                }
                long retryBudget = deadlineAt - System.currentTimeMillis();
                if (retryBudget < MIN_RETRY_BUDGET_MS) {
                    break;
                }
                continue;
            }
            failureReason = "http_" + status;
            break;
        }

        if (failureReason != null && lastErrorBody != null) {
            LoggerUtil.warn(log, "Gemini upstream failure reason=%s body=%s", failureReason, lastErrorBody);
        }
        return buildUpstreamErrorResponse(
                startedAt,
                failureReason != null ? failureReason : "unknown",
                "Gemini không phản hồi hợp lệ. Vui lòng thử lại sau.",
                null,
                lastErrorBody);
    }

    public Map<String, Object> streamSearch(String rawUserMessage, DeltaConsumer deltaConsumer) throws Exception {
        long startedAt = System.currentTimeMillis();
        String userMessage = normalizeText(rawUserMessage);
        if (userMessage == null || userMessage.isBlank()) {
            throw new IllegalArgumentException("Nội dung tìm kiếm không được để trống.");
        }

        AiCatalogContextCache.Snapshot snapshot = catalogContextCache.getSnapshot();
        String apiKey = resolveApiKey();
        if (apiKey == null) {
            return buildUpstreamErrorResponse(
                    startedAt,
                    "missing_api_key",
                    "Chưa có Gemini API key hợp lệ. Hãy cấu hình trong Admin hoặc biến môi trường GEMINI_API_KEY.",
                    null,
                    null);
        }

        List<Product> promptProducts = selectRelevantProducts(
                userMessage,
                snapshot.getActiveProducts(),
                snapshot.getCategoryNames(),
                MAX_AI_CONTEXT_PRODUCTS);
        String requestBody = mapper.writeValueAsString(buildGeminiStreamingPayload(
                userMessage,
                snapshot.getCategories(),
                promptProducts));

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse&key=" + apiKey))
                .timeout(Duration.ofSeconds(60))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(requestBody, StandardCharsets.UTF_8))
                .build();

        HttpResponse<InputStream> httpResponse;
        try {
            httpResponse = httpClient.send(request, HttpResponse.BodyHandlers.ofInputStream());
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
            return buildUpstreamErrorResponse(
                    startedAt,
                    "interrupted",
                    "Gemini stream bị gián đoạn. Vui lòng thử lại sau.",
                    null,
                    null);
        } catch (IOException ioe) {
            LoggerUtil.warn(log, "Không gọi được Gemini stream API.", ioe);
            return buildUpstreamErrorResponse(
                    startedAt,
                    "network_error",
                    "Không kết nối được tới Gemini. Vui lòng thử lại sau.",
                    null,
                    null);
        }

        int status = httpResponse.statusCode();
        if (status != 200) {
            String errorBody = readAllText(httpResponse.body());
            if (AI_CONFIG_ERROR_STATUS_CODES.contains(status)) {
                String errorMessage = extractGeminiErrorMessage(status, errorBody);
                LoggerUtil.warn(log, "Gemini stream config error status=%d body=%s", status, truncateForLog(errorBody));
                return buildUpstreamErrorResponse(
                        startedAt,
                        "http_" + status,
                        errorMessage,
                        status,
                        truncateForLog(errorBody));
            }
            LoggerUtil.warn(log, "Gemini stream HTTP error status=%d body=%s", status, truncateForLog(errorBody));
            return buildUpstreamErrorResponse(
                    startedAt,
                    "http_" + status,
                    "Gemini không phản hồi hợp lệ. Vui lòng thử lại sau.",
                    status,
                    truncateForLog(errorBody));
        }

        StringBuilder replyBuilder = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(httpResponse.body(), StandardCharsets.UTF_8))) {
            StringBuilder eventBuffer = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                if (line.isBlank()) {
                    processGeminiStreamEvent(eventBuffer.toString(), replyBuilder, deltaConsumer);
                    eventBuffer.setLength(0);
                    continue;
                }
                if (line.startsWith("data:")) {
                    eventBuffer.append(line.substring(5).stripLeading()).append('\n');
                }
            }
            processGeminiStreamEvent(eventBuffer.toString(), replyBuilder, deltaConsumer);
        }

        String reply = cleanAiReply(normalizeReply(replyBuilder.toString()));
        List<Product> finalProducts = selectRelevantProducts(
                userMessage,
                snapshot.getActiveProducts(),
                snapshot.getCategoryNames(),
                MAX_FALLBACK_PRODUCTS);
        List<Integer> suggestedIds = new ArrayList<>();
        for (Product product : finalProducts) {
            suggestedIds.add(product.getProductId());
        }
        List<Map<String, Object>> products = loadBriefProducts(suggestedIds);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("reply", reply);
        response.put("suggestedProductIds", extractValidProductIds(products));
        response.put("products", products);
        response.put("source", "gemini");
        response.put("fallback", false);
        response.put("latencyMs", System.currentTimeMillis() - startedAt);
        return response;
    }

    private String resolveApiKey() throws Exception {
        String apiKey = systemConfigDAO.getValue(AppConfig.CONFIG_GEMINI_API_KEY);
        if (apiKey != null) {
            apiKey = apiKey.trim();
            if (!apiKey.isEmpty()) {
                return apiKey;
            }
        }

        String envApiKey = System.getenv("GEMINI_API_KEY");
        if (envApiKey != null) {
            envApiKey = envApiKey.trim();
            if (!envApiKey.isEmpty()) {
                return envApiKey;
            }
        }

        if (AppConfig.GEMINI_API_KEY != null) {
            String appConfigApiKey = AppConfig.GEMINI_API_KEY.trim();
            if (!appConfigApiKey.isEmpty()) {
                return appConfigApiKey;
            }
        }

        return null;
    }

    private String extractGeminiErrorMessage(int status, String rawBody) {
        String parsedMessage = null;
        if (rawBody != null && !rawBody.isBlank()) {
            try {
                Map<String, Object> parsedBody = mapper.readValue(rawBody, Map.class);
                Object error = parsedBody.get("error");
                if (error instanceof Map<?, ?> errorMap) {
                    Object message = errorMap.get("message");
                    parsedMessage = normalizeText(message);
                    if (parsedMessage == null) {
                        parsedMessage = normalizeText(errorMap.get("status"));
                    }
                }
            } catch (Exception ignored) {
                // Use the truncated body below when JSON parsing fails.
            }
        }
        if (parsedMessage == null && rawBody != null && !rawBody.isBlank()) {
            parsedMessage = rawBody;
        }
        if (parsedMessage == null || parsedMessage.isBlank()) {
            return "Gemini từ chối yêu cầu với mã HTTP " + status + ".";
        }
        return "Gemini từ chối yêu cầu với mã HTTP " + status + ": " + parsedMessage;
    }

    private Map<String, Object> buildGeminiPayload(String userMessage,
                                                   List<model.entity.catalog.Category> categories,
                                                   List<Product> promptProducts) {
        StringBuilder catalogBuilder = new StringBuilder();
        catalogBuilder.append("=== DANH MỤC SẢN PHẨM PHÙ HỢP NHẤT ===\n");
        for (model.entity.catalog.Category category : categories) {
            catalogBuilder.append(String.format("- %s\n", normalizeText(category.getName())));
        }
        catalogBuilder.append("\n=== DANH SÁCH SẢN PHẨM KHỚP NHU CẦU (XẾP THEO ĐỘ PHÙ HỢP GIẢM DẦN) ===\n");
        for (Product product : promptProducts) {
            catalogBuilder.append(String.format(
                    "- ID: %d | Tên: %s | Nguồn gốc: %s | Khu vực: %s | Đã bán: %d | Đánh giá: %s | HSD: %s ngày | Mô tả: %s\n",
                    product.getProductId(),
                    normalizeText(product.getName()),
                    normalizeText(product.getOriginCountry()),
                    normalizeText(product.getOriginRegion()),
                    product.getSoldQuantity(),
                    product.getRating() == null ? "N/A" : product.getRating().toPlainString(),
                    product.getShelfLifeDays() == null ? "N/A" : product.getShelfLifeDays().toString(),
                    truncateForPrompt(product.getDescription(), 160)));
        }

        String systemInstruction = "Bạn là Trợ lý AI tư vấn mua hàng của MetaFruit.\n"
                + "Mục tiêu: chọn đúng sản phẩm trong danh sách cung cấp, ưu tiên độ phù hợp cao nhất với nhu cầu khách.\n"
                + "Quy tắc bắt buộc:\n"
                + "1. Chỉ được nhắc tên những sản phẩm thật sự xuất hiện trong danh sách bên dưới.\n"
                + "2. Không bịa tên sản phẩm, không tự thêm sản phẩm ngoài danh sách.\n"
                + "3. suggestedProductIds phải chỉ chứa ID của các sản phẩm đã cho sẵn.\n"
                + "4. Sắp xếp suggestedProductIds từ phù hợp nhất đến ít phù hợp hơn.\n"
                + "5. Reply phải thân thiện, ngắn gọn, tự nhiên, dễ mua hàng, và mô tả rõ lý do gợi ý.\n"
                + "6. Nếu câu hỏi ngoài phạm vi trái cây/thực phẩm sạch/bảo quản/chọn hàng, hãy từ chối lịch sự.\n"
                + "7. TUYỆT ĐỐI KHÔNG hiển thị hoặc đề cập ID (ví dụ: 'ID 12', 'ID: 5', '#1',...) trong văn bản reply gửi người dùng. ID chỉ được trả về trong mảng suggestedProductIds JSON.\n\n"
                + catalogBuilder;

        Map<String, Object> payload = new HashMap<>();
        Map<String, Object> systemInstructionMap = new HashMap<>();
        systemInstructionMap.put("parts", Collections.singletonList(Map.of("text", systemInstruction)));
        payload.put("systemInstruction", systemInstructionMap);
        payload.put("contents", Collections.singletonList(Map.of(
                "role", "user",
                "parts", Collections.singletonList(Map.of("text", userMessage))
        )));

        Map<String, Object> responseSchema = new HashMap<>();
        responseSchema.put("type", "OBJECT");
        responseSchema.put("properties", Map.of(
                "reply", Map.of("type", "STRING"),
                "suggestedProductIds", Map.of(
                        "type", "ARRAY",
                        "items", Map.of("type", "INTEGER"))));
        responseSchema.put("required", Arrays.asList("reply", "suggestedProductIds"));

        Map<String, Object> generationConfig = new HashMap<>();
        generationConfig.put("responseMimeType", "application/json");
        generationConfig.put("responseSchema", responseSchema);
        payload.put("generationConfig", generationConfig);
        return payload;
    }

    private Map<String, Object> buildGeminiStreamingPayload(String userMessage,
                                                            List<model.entity.catalog.Category> categories,
                                                            List<Product> promptProducts) {
        StringBuilder catalogBuilder = new StringBuilder();
        catalogBuilder.append("=== DANH MỤC SẢN PHẨM PHÙ HỢP NHẤT ===\n");
        for (model.entity.catalog.Category category : categories) {
            catalogBuilder.append(String.format("- %s\n", normalizeText(category.getName())));
        }
        catalogBuilder.append("\n=== DANH SÁCH SẢN PHẨM KHỚP NHU CẦU (XẾP THEO ĐỘ PHÙ HỢP GIẢM DẦN) ===\n");
        for (Product product : promptProducts) {
            catalogBuilder.append(String.format(
                    "- ID: %d | Tên: %s | Nguồn gốc: %s | Khu vực: %s | Đã bán: %d | Đánh giá: %s | HSD: %s ngày | Mô tả: %s\n",
                    product.getProductId(),
                    normalizeText(product.getName()),
                    normalizeText(product.getOriginCountry()),
                    normalizeText(product.getOriginRegion()),
                    product.getSoldQuantity(),
                    product.getRating() == null ? "N/A" : product.getRating().toPlainString(),
                    product.getShelfLifeDays() == null ? "N/A" : product.getShelfLifeDays().toString(),
                    truncateForPrompt(product.getDescription(), 160)));
        }

        String systemInstruction = "Bạn là Trợ lý AI tư vấn mua hàng của MetaFruit.\n"
                + "Mục tiêu: chọn đúng sản phẩm trong danh sách cung cấp, ưu tiên độ phù hợp cao nhất với nhu cầu khách.\n"
                + "Quy tắc bắt buộc:\n"
                + "1. Chỉ được nhắc tên những sản phẩm thật sự xuất hiện trong danh sách bên dưới.\n"
                + "2. Không bịa tên sản phẩm, không tự thêm sản phẩm ngoài danh sách.\n"
                + "3. suggestedProductIds phải chỉ chứa ID của các sản phẩm đã cho sẵn.\n"
                + "4. Sắp xếp suggestedProductIds từ phù hợp nhất đến ít phù hợp hơn.\n"
                + "5. Reply phải thân thiện, ngắn gọn, tự nhiên, dễ mua hàng, và mô tả rõ lý do gợi ý.\n"
                + "6. Nếu câu hỏi ngoài phạm vi trái cây/thực phẩm sạch/bảo quản/chọn hàng, hãy từ chối lịch sự.\n"
                + "7. TUYỆT ĐỐI KHÔNG hiển thị hoặc đề cập ID (ví dụ: 'ID 12', 'ID: 5', '#1',...) trong văn bản reply gửi người dùng. ID chỉ được trả về trong mảng suggestedProductIds JSON.\n"
                + "Hãy trả lời tự nhiên như đang trò chuyện trực tiếp với khách hàng.\n\n"
                + catalogBuilder;

        Map<String, Object> payload = new HashMap<>();
        Map<String, Object> systemInstructionMap = new HashMap<>();
        systemInstructionMap.put("parts", Collections.singletonList(Map.of("text", systemInstruction)));
        payload.put("systemInstruction", systemInstructionMap);
        payload.put("contents", Collections.singletonList(Map.of(
                "role", "user",
                "parts", Collections.singletonList(Map.of("text", userMessage))
        )));
        return payload;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> buildGeminiResponse(String rawBody, long startedAt) throws Exception {
        Map<String, Object> geminiResponse = mapper.readValue(rawBody, Map.class);
        List<Map<String, Object>> candidates = (List<Map<String, Object>>) geminiResponse.get("candidates");
        if (candidates == null || candidates.isEmpty()) {
            return buildUpstreamErrorResponse(
                    startedAt,
                    "empty_candidates",
                    "Gemini trả về phản hồi rỗng. Vui lòng thử lại sau.",
                    null,
                    null);
        }

        Map<String, Object> candidate = candidates.get(0);
        Map<String, Object> contentMap = (Map<String, Object>) candidate.get("content");
        List<Map<String, Object>> partsList = contentMap != null ? (List<Map<String, Object>>) contentMap.get("parts") : null;
        String jsonText = partsList != null && !partsList.isEmpty() ? normalizeText(partsList.get(0).get("text")) : null;
        if (jsonText == null) {
            return buildUpstreamErrorResponse(
                    startedAt,
                    "empty_text",
                    "Gemini trả về nội dung không hợp lệ. Vui lòng thử lại sau.",
                    null,
                    null);
        }

        Map<String, Object> aiResult = mapper.readValue(jsonText, Map.class);
        String reply = normalizeReply(aiResult.get("reply"));
        List<Integer> suggestedIds = extractSuggestedProductIds(aiResult.get("suggestedProductIds"));
        List<Map<String, Object>> products = loadBriefProducts(suggestedIds);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("reply", reply);
        response.put("suggestedProductIds", extractValidProductIds(products));
        response.put("products", products);
        response.put("source", "gemini");
        response.put("fallback", false);
        response.put("latencyMs", System.currentTimeMillis() - startedAt);
        return response;
    }

    @SuppressWarnings("unchecked")
    private void processGeminiStreamEvent(String eventData, StringBuilder replyBuilder, DeltaConsumer deltaConsumer) throws Exception {
        String normalizedEvent = normalizeText(eventData);
        if (normalizedEvent == null || "[DONE]".equalsIgnoreCase(normalizedEvent)) {
            return;
        }

        Map<String, Object> chunk = mapper.readValue(normalizedEvent, Map.class);
        List<Map<String, Object>> candidates = (List<Map<String, Object>>) chunk.get("candidates");
        if (candidates == null || candidates.isEmpty()) {
            return;
        }

        Map<String, Object> candidate = candidates.get(0);
        Map<String, Object> contentMap = (Map<String, Object>) candidate.get("content");
        List<Map<String, Object>> partsList = contentMap != null ? (List<Map<String, Object>>) contentMap.get("parts") : null;
        if (partsList == null || partsList.isEmpty()) {
            return;
        }

        String text = normalizeText(partsList.get(0).get("text"));
        if (text != null) {
            replyBuilder.append(text);
            if (deltaConsumer != null) {
                deltaConsumer.accept(text);
            }
        }
    }

    private String readAllText(InputStream body) throws IOException {
        if (body == null) {
            return null;
        }
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(body, StandardCharsets.UTF_8))) {
            StringBuilder builder = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                if (builder.length() > 0) {
                    builder.append('\n');
                }
                builder.append(line);
            }
            return builder.toString();
        }
    }

    private Map<String, Object> buildFallbackResponse(String userMessage,
                                                      AiCatalogContextCache.Snapshot snapshot,
                                                      long startedAt,
                                                      String fallbackReason) throws Exception {
        List<Product> fallbackProducts = selectRelevantProducts(
                userMessage,
                snapshot.getActiveProducts(),
                snapshot.getCategoryNames(),
                MAX_FALLBACK_PRODUCTS);
        List<Integer> suggestedIds = new ArrayList<>();
        for (Product product : fallbackProducts) {
            suggestedIds.add(product.getProductId());
        }
        List<Map<String, Object>> products = loadBriefProducts(suggestedIds);
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("reply", buildFallbackReply(userMessage, fallbackProducts));
        response.put("suggestedProductIds", extractValidProductIds(products));
        response.put("products", products);
        response.put("source", "fallback");
        response.put("fallback", true);
        response.put("latencyMs", System.currentTimeMillis() - startedAt);
        response.put("fallbackReason", fallbackReason);
        return response;
    }

    private Map<String, Object> buildUpstreamErrorResponse(long startedAt,
                                                           String errorCode,
                                                           String errorMessage,
                                                           Integer upstreamStatus,
                                                           String upstreamBody) {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("reply", null);
        response.put("suggestedProductIds", Collections.emptyList());
        response.put("products", Collections.emptyList());
        response.put("source", "upstream_error");
        response.put("fallback", false);
        response.put("latencyMs", System.currentTimeMillis() - startedAt);
        response.put("errorCode", errorCode);
        response.put("errorMessage", normalizeText(errorMessage) != null
                ? normalizeText(errorMessage)
                : "Gemini không phản hồi được.");
        if (upstreamStatus != null) {
            response.put("upstreamStatus", upstreamStatus);
        }
        if (upstreamBody != null && !upstreamBody.isBlank()) {
            response.put("upstreamBody", upstreamBody);
        }
        return response;
    }

    private List<Map<String, Object>> loadBriefProducts(List<Integer> suggestedIds) throws Exception {
        if (suggestedIds == null || suggestedIds.isEmpty()) {
            return Collections.emptyList();
        }
        List<Map<String, Object>> briefProducts = productDAO.findBriefProductsByIds(suggestedIds);
        if (briefProducts == null || briefProducts.isEmpty()) {
            return Collections.emptyList();
        }
        Map<Integer, Map<String, Object>> briefById = new HashMap<>();
        for (Map<String, Object> product : briefProducts) {
            Object idValue = product.get("productId");
            if (idValue instanceof Number number) {
                briefById.put(number.intValue(), product);
            }
        }
        List<Map<String, Object>> ordered = new ArrayList<>();
        for (Integer suggestedId : suggestedIds) {
            Map<String, Object> product = briefById.get(suggestedId);
            if (product != null) {
                ordered.add(product);
            }
        }
        if (ordered.size() > MAX_FALLBACK_PRODUCTS) {
            return new ArrayList<>(ordered.subList(0, MAX_FALLBACK_PRODUCTS));
        }
        return ordered;
    }

    private List<Integer> extractValidProductIds(List<Map<String, Object>> products) {
        List<Integer> ids = new ArrayList<>();
        if (products == null) {
            return ids;
        }
        for (Map<String, Object> product : products) {
            Object value = product.get("productId");
            if (value instanceof Number number) {
                ids.add(number.intValue());
            }
        }
        return ids;
    }

    private String normalizeText(Object value) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value).trim();
        return text.isEmpty() ? null : text;
    }

    private String cleanAiReply(String rawText) {
        if (rawText == null || rawText.isBlank()) {
            return rawText;
        }
        return rawText.replaceAll("(?i)\\b(ID|mã|sản phẩm ID|Mã SP)[:\\s]*#?\\d+\\b", "")
                      .replaceAll("(?i)\\b#\\d+\\b", "")
                      .replaceAll("  +", " ")
                      .trim();
    }

    private String normalizeReply(Object value) {
        String reply = normalizeText(value);
        if (reply != null) {
            reply = cleanAiReply(reply);
        }
        return reply != null && !reply.isBlank() ? reply : "Mình chưa nhận được câu trả lời hợp lệ từ AI. Vui lòng thử lại.";
    }

    private List<Integer> extractSuggestedProductIds(Object rawIds) {
        List<Integer> ids = new ArrayList<>();
        if (!(rawIds instanceof List<?> rawList)) {
            return ids;
        }
        for (Object rawId : rawList) {
            if (rawId instanceof Number number) {
                ids.add(number.intValue());
                continue;
            }
            if (rawId instanceof String text) {
                try {
                    ids.add(Integer.parseInt(text.trim()));
                } catch (NumberFormatException ignored) {
                    // Bỏ qua giá trị không hợp lệ.
                }
            }
        }
        return ids;
    }

    private List<Product> selectRelevantProducts(String userMessage, List<Product> activeProducts,
                                                 Map<Integer, String> categoryNames, int limit) {
        if (activeProducts == null || activeProducts.isEmpty() || limit <= 0) {
            return Collections.emptyList();
        }

        String normalizedMessage = normalizeSearchText(userMessage);
        List<String> keywords = extractSearchKeywords(normalizedMessage);
        List<ScoredProduct> scoredProducts = new ArrayList<>();

        for (Product product : activeProducts) {
            String categoryName = categoryNames.get(product.getCategoryId());
            int score = scoreFallbackProduct(product, normalizedMessage, keywords, categoryName);
            if (score > 0) {
                scoredProducts.add(new ScoredProduct(product, score));
            }
        }

        if (scoredProducts.isEmpty()) {
            List<Product> sorted = new ArrayList<>(activeProducts);
            sorted.sort((left, right) -> {
                int soldCompare = Integer.compare(right.getSoldQuantity(), left.getSoldQuantity());
                if (soldCompare != 0) {
                    return soldCompare;
                }
                return Integer.compare(right.getProductId(), left.getProductId());
            });
            return new ArrayList<>(sorted.subList(0, Math.min(limit, sorted.size())));
        }

        scoredProducts.sort((left, right) -> {
            int scoreCompare = Integer.compare(right.score(), left.score());
            if (scoreCompare != 0) {
                return scoreCompare;
            }
            int soldCompare = Integer.compare(right.product().getSoldQuantity(), left.product().getSoldQuantity());
            if (soldCompare != 0) {
                return soldCompare;
            }
            return Integer.compare(right.product().getProductId(), left.product().getProductId());
        });

        List<Product> selected = new ArrayList<>();
        for (ScoredProduct scored : scoredProducts) {
            if (selected.size() >= limit) {
                break;
            }
            selected.add(scored.product());
        }
        return selected;
    }

    private int scoreFallbackProduct(Product product, String normalizedMessage, List<String> keywords,
                                     String categoryName) {
        String normalizedName = normalizeSearchText(product.getName());
        String normalizedDescription = normalizeSearchText(product.getDescription());
        String normalizedOriginCountry = normalizeSearchText(product.getOriginCountry());
        String normalizedOriginRegion = normalizeSearchText(product.getOriginRegion());
        String normalizedStorageInstruction = normalizeSearchText(product.getStorageInstruction());
        String normalizedCategory = normalizeSearchText(categoryName);
        boolean importedProduct = product.getIsImported();

        String haystack = String.join(" ",
                normalizedName,
                normalizedDescription,
                normalizedOriginCountry,
                normalizedOriginRegion,
                normalizedStorageInstruction,
                normalizedCategory).trim();

        int score = 0;
        if (!normalizedMessage.isEmpty() && haystack.contains(normalizedMessage)) {
            score += 6;
        }
        if (!normalizedName.isEmpty() && !normalizedMessage.isEmpty() && normalizedName.contains(normalizedMessage)) {
            score += 4;
        }
        if (!normalizedCategory.isEmpty() && !normalizedMessage.isEmpty() && normalizedCategory.contains(normalizedMessage)) {
            score += 2;
        }

        boolean wantsImported = normalizedMessage.contains("nhap khau") || normalizedMessage.contains("import");
        if (wantsImported) {
            if (importedProduct || normalizedName.contains("nhap khau") || isImportedOrigin(normalizedOriginCountry)) {
                score += 5;
            } else if (!normalizedOriginCountry.isBlank() || importedProduct) {
                score += 1;
            }
        } else if (importedProduct) {
            score += 1;
        }

        boolean wantsVitaminC = normalizedMessage.contains("vitamin c");
        if (wantsVitaminC && containsAny(normalizedName, VITAMIN_C_HINTS)) {
            score += 4;
        } else if (wantsVitaminC && containsAny(normalizedDescription, VITAMIN_C_HINTS)) {
            score += 2;
        }

        for (String keyword : keywords) {
            if (keyword.length() < 3) {
                continue;
            }
            if (normalizedName.contains(keyword)) {
                score += 4;
            } else if (haystack.contains(keyword)) {
                score += 2;
            }
        }

        return score;
    }

    private List<String> extractSearchKeywords(String normalizedText) {
        List<String> keywords = new ArrayList<>();
        if (normalizedText == null || normalizedText.isBlank()) {
            return keywords;
        }
        for (String token : normalizedText.split(" ")) {
            if (token == null || token.isBlank() || token.length() < 3) {
                continue;
            }
            if (AI_SEARCH_STOP_WORDS.contains(token)) {
                continue;
            }
            keywords.add(token);
        }
        return keywords;
    }

    private String normalizeSearchText(String text) {
        if (text == null || text.isBlank()) {
            return "";
        }
        return Normalizer.normalize(text, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .replace('đ', 'd')
                .replace('Đ', 'd')
                .toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9]+", " ")
                .replaceAll("\\s+", " ")
                .trim();
    }

    private String buildFallbackReply(String userMessage, List<Product> products) {
        if (products == null || products.isEmpty()) {
            return "Hiện tại các sản phẩm phù hợp đang tạm hết hoặc chưa sẵn sàng. Bạn thử đổi từ khóa để mình gợi ý chính xác hơn nhé.";
        }
        String intentLabel = deriveFallbackIntentLabel(userMessage);
        List<String> highlightNames = extractProductNames(products, 3);
        StringBuilder reply = new StringBuilder();
        reply.append("MetaFruit đã chọn ra các sản phẩm phù hợp nhất");
        if (!intentLabel.isBlank()) {
            reply.append(" cho nhu cầu ").append(intentLabel);
        }
        reply.append(". Nổi bật gồm ").append(joinNaturalLanguage(highlightNames)).append(".");
        return reply.toString();
    }

    private String deriveFallbackIntentLabel(String userMessage) {
        String normalizedMessage = normalizeSearchText(userMessage);
        if (normalizedMessage.isBlank()) {
            return "";
        }
        boolean wantsImported = normalizedMessage.contains("nhap khau") || normalizedMessage.contains("import");
        boolean wantsVitaminC = normalizedMessage.contains("vitamin c");
        if (wantsImported && wantsVitaminC) {
            return "trái cây nhập khẩu giàu vitamin C";
        }
        if (wantsVitaminC) {
            return "trái cây giàu vitamin C";
        }
        if (wantsImported) {
            return "trái cây nhập khẩu";
        }
        if (normalizedMessage.contains("nguoi om")) {
            return "quà cho người ốm";
        }
        return "hiện tại";
    }

    private List<String> extractProductNames(List<Product> products, int limit) {
        List<String> names = new ArrayList<>();
        if (products == null || products.isEmpty() || limit <= 0) {
            return names;
        }
        for (Product product : products) {
            if (names.size() >= limit) {
                break;
            }
            String name = normalizeText(product.getName());
            if (name != null && !name.isBlank()) {
                names.add(name);
            }
        }
        return names;
    }

    private String joinNaturalLanguage(List<String> values) {
        if (values == null || values.isEmpty()) {
            return "";
        }
        if (values.size() == 1) {
            return values.get(0);
        }
        if (values.size() == 2) {
            return values.get(0) + " và " + values.get(1);
        }
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < values.size(); i++) {
            if (i > 0) {
                builder.append(i == values.size() - 1 ? " và " : ", ");
            }
            builder.append(values.get(i));
        }
        return builder.toString();
    }

    private boolean containsAny(String haystack, Set<String> needles) {
        if (haystack == null || haystack.isBlank() || needles == null || needles.isEmpty()) {
            return false;
        }
        for (String needle : needles) {
            if (needle != null && !needle.isBlank() && haystack.contains(needle)) {
                return true;
            }
        }
        return false;
    }

    private boolean isImportedOrigin(String normalizedOriginCountry) {
        if (normalizedOriginCountry == null || normalizedOriginCountry.isBlank()) {
            return false;
        }
        return !normalizedOriginCountry.contains("viet nam")
                && !normalizedOriginCountry.contains("vietnam");
    }

    private String truncateForPrompt(String text, int maxLength) {
        String value = normalizeText(text);
        if (value == null) {
            return "";
        }
        if (maxLength <= 0 || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength).trim() + "...";
    }

    private String truncateForLog(String text) {
        if (text == null) {
            return "";
        }
        String sanitized = text.replaceAll("[\\r\\n\\t]+", " ").trim();
        if (sanitized.length() <= 300) {
            return sanitized;
        }
        return sanitized.substring(0, 300) + "...";
    }

    private record ScoredProduct(Product product, int score) {}
}
