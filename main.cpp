#include <windows.h>
#include "backends/imgui_impl_opengl3.h"

#include <glad/glad.h>

#include <GLFW/glfw3.h>
#include <imgui.h>
#include <backends/imgui_impl_glfw.h>

#include <fstream>
#include <sstream>
#include <iostream>

std::string LoadShaderSource(const char* filename);
GLFWwindow* InitWindow();
void DrawFPSChart(std::vector<float> FPSHistory);
GLuint CreateScene(std::string FileName);

int main() {
	auto window = InitWindow();
	if (window == nullptr) {
		return -1;
	}

	GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);

	std::string vertexShaderSource = LoadShaderSource("../shader/vertex.glsl");
	const GLchar* vShaderCode = vertexShaderSource.c_str();
	glShaderSource(vertexShader, 1, &vShaderCode, NULL);
	glCompileShader(vertexShader);

	auto scene1 = CreateScene("../shader/scenes/scene1.glsl");
	auto scene2 = CreateScene("../shader/scenes/scene2.glsl");
	auto scene3 = CreateScene("../shader/scenes/scene3.glsl");

	GLuint scene1Program = glCreateProgram();

	glAttachShader(scene1Program, vertexShader);
	glAttachShader(scene1Program, scene1);

	glLinkProgram(scene1Program);

	GLuint scene2Program = glCreateProgram();

	glAttachShader(scene2Program, vertexShader);
	glAttachShader(scene2Program, scene2);

	glLinkProgram(scene2Program);

	GLuint scene3Program = glCreateProgram();

	glAttachShader(scene3Program, vertexShader);
	glAttachShader(scene3Program, scene3);

	glLinkProgram(scene3Program);

	GLuint sceneProgram = scene1Program;

	float quadVertices[] = {
		-1.0f, -1.0f,   0.0f, 0.0f,
		 1.0f, -1.0f,   1.0f, 0.0f,
		 1.0f,  1.0f,   1.0f, 1.0f,
		-1.0f,  1.0f,   0.0f, 1.0f
	};

	unsigned int quadIndices[] = {
		0, 1, 2,
		2, 3, 0
	};

	unsigned int VAO, VBO, EBO;
	glGenVertexArrays(1, &VAO);
	glGenBuffers(1, &VBO);
	glGenBuffers(1, &EBO);

	glBindVertexArray(VAO);

	glBindBuffer(GL_ARRAY_BUFFER, VBO);
	glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(quadIndices), quadIndices, GL_STATIC_DRAW);

	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
	glEnableVertexAttribArray(0);

	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
	glEnableVertexAttribArray(1);

	glBindVertexArray(0);

	time_t start = clock();
	while (!glfwWindowShouldClose(window)) {
		glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);

		GLuint queryID[2];
		glGenQueries(2, queryID);

		glQueryCounter(queryID[0], GL_TIMESTAMP);

		glUseProgram(sceneProgram);
		GLint timeLocation = glGetUniformLocation(sceneProgram, "iTime");
		glUniform1f(timeLocation, (clock() - start) / 1000.f);

		glBindVertexArray(VAO);
		glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

		glQueryCounter(queryID[1], GL_TIMESTAMP);

		GLint available = 0;
		while (!available) {
			glGetQueryObjectiv(queryID[1], GL_QUERY_RESULT_AVAILABLE, &available);
		}

		GLuint64 startTime, endTime;
		glGetQueryObjectui64v(queryID[0], GL_QUERY_RESULT, &startTime);
		glGetQueryObjectui64v(queryID[1], GL_QUERY_RESULT, &endTime);

		GLuint64 elapsedTime = endTime - startTime;
		double elapsedMs = static_cast<double>(elapsedTime) / 1000000.0;

		ImGui_ImplOpenGL3_NewFrame();
		ImGui_ImplGlfw_NewFrame();

		ImGui::NewFrame();

		ImGui::Begin("Scene");

		static int item = 0;
		const char* items[] = { "Scene 1", "Scene 2", "Scene 3" };

		ImGui::Combo("Scene to render", &item, items, IM_ARRAYSIZE(items));
		if (item == 0) {
			sceneProgram = scene1Program;
		}
		if (item == 1) {
			sceneProgram = scene2Program;
		}
		if (item == 2) {
			sceneProgram = scene3Program;
		}

		ImGui::End();

		static std::vector<float> frameRateHistory;
		frameRateHistory.push_back(1.f / (elapsedMs / 1000.f));
		if (frameRateHistory.size() > 500) {
			frameRateHistory.erase(frameRateHistory.begin());
		}

		DrawFPSChart(frameRateHistory);

		ImGui::Render();

		ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

		glfwSwapBuffers(window);
		glfwPollEvents();
	}

    return 0;
}

std::string LoadShaderSource(const char* filename) {
	std::ifstream file(filename);
	if (!file.is_open()) {
		return "";
	}

	std::stringstream buffer;
	buffer << file.rdbuf();
	return buffer.str();
}

GLFWwindow* InitWindow() {
#if defined(IMGUI_IMPL_OPENGL_ES2)
	// GL ES 2.0 + GLSL 100 (WebGL 1.0)
	const char* glsl_version = "#version 100";
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
	glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
#elif defined(IMGUI_IMPL_OPENGL_ES3)
	// GL ES 3.0 + GLSL 300 es (WebGL 2.0)
	const char* glsl_version = "#version 300 es";
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
	glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
#elif defined(__APPLE__)
	// GL 3.2 + GLSL 150
	const char* glsl_version = "#version 150";
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);  // 3.2+ only
	glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);            // Required on Mac
#else
	// GL 3.0 + GLSL 130
	const char* glsl_version = "#version 130";
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
	//glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);  // 3.2+ only
	//glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);            // 3.0+ only
#endif


	int success = glfwInit();
	if (!success) {
		std::cerr << "Error initializing GLFW" << std::endl;

		return nullptr;
	}

	auto window = glfwCreateWindow(1200, 700, "VAS : Visible Angle Shading", nullptr, nullptr);
	glfwMakeContextCurrent(window);

	ImGui::CreateContext();

	ImGuiIO& io = ImGui::GetIO();
	io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
	io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;

	ImGui_ImplGlfw_InitForOpenGL(window, true);
	ImGui_ImplOpenGL3_Init(glsl_version);

	if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
		glfwTerminate();
		return nullptr;
	}

	glfwSetWindowSizeCallback(window, [](GLFWwindow* window, int width, int height) -> void {
		glfwMakeContextCurrent(window);
		glViewport(0, 0, width, height);
	});

	return window;
}

void DrawFPSChart(std::vector<float> FPSHistory)
{
	ImGui::Begin("FPS Monitor");

	float avgFPS = 0.0f;
	if (!FPSHistory.empty()) {
		for (float fps : FPSHistory) avgFPS += fps;
		avgFPS /= FPSHistory.size();
	}

	float currentFPS = FPSHistory.empty() ? 0.0f : FPSHistory.back();

	ImGui::Text("Current: %.1f FPS | Avg: %.1f FPS", currentFPS, avgFPS);

	float minFPS = *std::min_element(FPSHistory.begin(), FPSHistory.end());
	float maxFPS = *std::max_element(FPSHistory.begin(), FPSHistory.end());
	float rangePadding = std::max(10.0f, (maxFPS - minFPS) * 0.1f); // 10%的填充

	char overlay[32];
	snprintf(overlay, sizeof(overlay), "%.1f FPS", currentFPS);

	ImGui::PlotLines(
		"##FPS_Chart",
		FPSHistory.data(),
		static_cast<int>(FPSHistory.size()),
		0,
		overlay,
		std::max(0.0f, minFPS - rangePadding),
		maxFPS + rangePadding,
		ImVec2(0, 150.0f)
	);

	float frameTime = 1000.0f / (currentFPS > 0 ? currentFPS : 1.0f);
	ImGui::Text("Frame time: %.2f ms", frameTime);

	ImGui::End();
}
GLuint CreateScene(std::string FileName) {
	GLuint        scene       = glCreateShader(GL_FRAGMENT_SHADER);
	std::string   code        = LoadShaderSource(FileName.c_str());
	const GLchar *fShaderCode = code.c_str();
	glShaderSource(scene, 1, &fShaderCode, nullptr);
	glCompileShader(scene);

	int  success;
	char infoLog[512];
	glGetShaderiv(scene, GL_COMPILE_STATUS, &success);
	if (!success) {
		glGetShaderInfoLog(scene, 512, nullptr, infoLog);
		MessageBoxA(nullptr, infoLog, "Error", MB_OK + 16);
	}

	return scene;
}