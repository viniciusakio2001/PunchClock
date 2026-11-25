from django.contrib.auth.models import AbstractUser
from django.db import models
from .fusos import FUSOS_HORARIOS
from django.conf import settings

class Empresa(models.Model):
    razaosocial = models.CharField(max_length=200)
    cnpj = models.CharField('CNPJ',max_length=14, unique=True) 
    fuso_horario = models.CharField(max_length=100, choices=FUSOS_HORARIOS, default='America/Sao_Paulo')
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'empresas'

    def __str__(self) -> str:
        return self.razaosocial


class Cargo(models.Model):
    descricao = models.CharField(max_length=100)

    class Meta:
        db_table = 'cargo'

    def __str__(self):
        return self.descricao

class Usuario(AbstractUser):
    class Perfil(models.TextChoices):
        FUNCIONARIO = 'FUNCIONARIO', 'Funcionário'
        GESTOR = 'GESTOR', 'Gestor'
        RH = 'RH', 'Recursos Humanos'
        ADMINISTRADOR = 'ADMINISTRADOR', 'Administrador'

    class Regime(models.TextChoices):
        CLT = 'CLT', 'CLT'
        PJ = 'PJ', 'PJ'
        AUTONOMO = 'AUTONOMO', 'Autônomo'
        MENOR_APRENDIZ = 'MENOR_APRENDIZ', 'Menor Aprendiz'
        ESTAGIO = 'ESTAGIO', 'Estágio'
    
    username = models.CharField("login", max_length=32, unique=True)
    email = models.EmailField(unique=True)
    perfil = models.CharField(max_length=20, choices=Perfil.choices, default=Perfil.FUNCIONARIO)
    regime = models.CharField(max_length=20, choices=Regime.choices, default=Regime.CLT)
    cpf = models.CharField(max_length=20, unique=True)
    cargo = models.ForeignKey(Cargo, on_delete=models.PROTECT)
    carga_horaria = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)

    REQUIRED_FIELDS = ['email', 'perfil', 'regime', 'cpf', 'cargo', 'carga_horaria']

    class Meta:
        db_table = 'usuarios'

class Configuracao(models.Model):
    class TipoDado(models.TextChoices):
        INTEIRO = 'INTEIRO', 'Numero Inteiro'
        BOOLEANO = 'BOOLEANO', 'Sim ou Não'
        DIA_DO_MES = 'DIA_DO_MES', 'Dia do Mês'
        MES_REFERENCIA = 'MES_REFERENCIA', 'Mês de Referência'
        COMPORTAMENTO = 'COMPORTAMENTO', 'Comportamento'

    chave = models.CharField(max_length=60, unique=True)
    valor = models.CharField(max_length=200)
    tipo_dado = models.CharField(max_length=20, choices=TipoDado.choices)
    atualizado_em = models.DateTimeField(auto_now=True)
    atualizado_por = models.ForeignKey(settings.AUTH_USER_MODEL,  null=True, blank=True, on_delete=models.SET_NULL, related_name='configuracoes_alteradas')

    class Meta:
        db_table = 'configuracoes'

    def __str__(self) -> str:
        return f"{self.chave} = {self.valor}"

class HistoricoConfiguracao(models.Model):
    configuracao = models.ForeignKey(Configuracao, on_delete=models.PROTECT, related_name='historico')
    valor_anterior = models.CharField(max_length=200)
    valor_novo = models.CharField(max_length=200)
    alterado_por = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='historico_configuracoes')
    alterado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'historico_configuracoes'

    def __str__(self) -> str:
        return f"{self.configuracao.chave}: {self.valor_anterior} -> {self.valor_novo}"