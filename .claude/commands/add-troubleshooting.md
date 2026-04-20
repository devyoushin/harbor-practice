Harbor 트러블슈팅 케이스를 추가합니다.

**사용법**: `/add-troubleshooting <증상 설명>`

**예시**: `/add-troubleshooting docker push 인증 실패`

다음 형식으로 작성하고 `troubleshooting-guide.md`에 추가하세요:

```markdown
### <증상>

**원인**: <근본 원인>

**확인 방법**:
\`\`\`bash
kubectl logs -n harbor -l component=core
kubectl get pvc -n harbor
curl -u admin:<pw> https://harbor.example.com/api/v2.0/health
\`\`\`

**해결**: <해결 방법>
**예방**: <재발 방지>
```
